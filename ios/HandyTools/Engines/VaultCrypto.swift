import Foundation
import CryptoKit
import Security
import LocalAuthentication

/// Real encryption for the Vault: every item is sealed with AES-GCM under a 256-bit key that lives
/// only in this device's Keychain and can only be read after Face ID / Touch ID / passcode
/// (`WhenPasscodeSetThisDeviceOnly` + biometry-gated access control). No passcode → no vault.
/// Backups and other devices never see a usable key, so the files are noise anywhere else.
enum VaultCrypto {
    static let service = "com.tenzy.vault.key"
    static let account = "master"

    enum VaultError: LocalizedError {
        case noPasscode, cancelled, keychain(OSStatus), corrupt
        var errorDescription: String? {
            switch self {
            case .noPasscode: return "Set a device passcode (Settings › Face ID & Passcode) to use the Vault."
            case .cancelled: return "Unlock was cancelled."
            case .keychain(let s): return "Keychain error \(s)."
            case .corrupt: return "This item couldn't be decrypted."
            }
        }
    }

    // MARK: key management

    /// Authenticate an LAContext exactly once, via a single Face ID / Touch ID / passcode prompt.
    private static func authenticate(_ ctx: LAContext, reason: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, error in
                if ok { cont.resume() }
                else if let e = error as? LAError, e.code == .userCancel || e.code == .appCancel || e.code == .systemCancel {
                    cont.resume(throwing: VaultError.cancelled)
                } else { cont.resume(throwing: VaultError.cancelled) }
            }
        }
    }

    /// Fetches the vault key, prompting for biometrics/passcode ONCE; creates it on first use.
    /// The context is authenticated up front and reused for the keychain operation, so the user sees
    /// a single prompt instead of one per keychain access.
    static func unlockKey(reason: String = "Unlock your vault") async throws -> SymmetricKey {
        let ctx = LAContext()
        ctx.localizedReason = reason
        ctx.touchIDAuthenticationAllowableReuseDuration = 10   // reuse this auth for quick follow-ups
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { throw VaultError.noPasscode }

        // One prompt, here. The keychain read/write below reuses this authenticated context and does
        // NOT pass kSecUseOperationPrompt, so iOS does not evaluate biometrics a second time.
        try await authenticate(ctx, reason: reason)

        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account,
                                kSecReturnData as String: true, kSecUseAuthenticationContext as String: ctx]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let d = out as? Data, d.count == 32 else { throw VaultError.corrupt }
            return SymmetricKey(data: d)
        case errSecItemNotFound:
            // first run: generate and store behind biometry (falls back to passcode)
            let key = SymmetricKey(size: .bits256)
            let data = key.withUnsafeBytes { Data($0) }
            guard let ac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [.userPresence], nil) else { throw VaultError.keychain(-1) }
            q = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account,
                 kSecValueData as String: data, kSecAttrAccessControl as String: ac, kSecUseAuthenticationContext as String: ctx]
            let add = SecItemAdd(q as CFDictionary, nil)
            guard add == errSecSuccess else { throw VaultError.keychain(add) }
            return key
        case errSecUserCanceled, errSecAuthFailed:
            throw VaultError.cancelled
        default:
            throw VaultError.keychain(status)
        }
    }

    // MARK: sealing

    static func seal(_ plain: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plain, using: key)
        guard let combined = box.combined else { throw VaultError.corrupt }
        return combined
    }
    static func open(_ sealed: Data, with key: SymmetricKey) throws -> Data {
        guard let box = try? AES.GCM.SealedBox(combined: sealed) else { throw VaultError.corrupt }
        do { return try AES.GCM.open(box, using: key) } catch { throw VaultError.corrupt }
    }

    /// Overwrite then unlink — a best-effort shred for flash storage.
    static func shred(_ url: URL) {
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int, size > 0, size < 50_000_000, let h = try? FileHandle(forWritingTo: url) {
            try? h.write(contentsOf: Data(count: size)); try? h.synchronize(); try? h.close()
        }
        try? FileManager.default.removeItem(at: url)
    }
}

/// The encrypted index + blobs on disk. Everything under Documents/Vault is ciphertext.
@MainActor final class VaultStore: ObservableObject {
    struct Item: Identifiable, Codable, Equatable {
        enum Kind: String, Codable { case note, secret, photo, document }
        var id = UUID()
        var kind: Kind
        var title: String
        var text: String = ""          // note body or secret value (encrypted with the index)
        var file: String? = nil        // encrypted blob filename for photo/document
        var fileExt: String? = nil     // original extension for documents
        var date = Date()
        var bytes: Int = 0
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var unlocked = false
    @Published var errorText: String?
    private var key: SymmetricKey?
    nonisolated static let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        return d
    }()
    private var indexURL: URL { Self.dir.appendingPathComponent("index.enc") }

    func unlock() async {
        errorText = nil
        do {
            let k = try await VaultCrypto.unlockKey()
            key = k
            if let data = try? Data(contentsOf: indexURL) {
                let plain = try VaultCrypto.open(data, with: k)
                items = (try? JSONDecoder().decode([Item].self, from: plain)) ?? []
            } else { items = [] }
            unlocked = true
        } catch { errorText = error.localizedDescription; unlocked = false }
    }

    func lock() { key = nil; items = []; unlocked = false }

    private func persist() {
        guard let key, let plain = try? JSONEncoder().encode(items), let sealed = try? VaultCrypto.seal(plain, with: key) else { return }
        try? sealed.write(to: indexURL, options: [.completeFileProtection, .atomic])
    }

    func addNote(title: String, text: String) { items.insert(Item(kind: .note, title: title.isEmpty ? "Note" : title, text: text), at: 0); persist() }
    func addSecret(title: String, value: String) { items.insert(Item(kind: .secret, title: title.isEmpty ? "Secret" : title, text: value), at: 0); persist() }

    func addBlob(_ data: Data, kind: Item.Kind, title: String, ext: String?) {
        guard let key, let sealed = try? VaultCrypto.seal(data, with: key) else { return }
        let name = UUID().uuidString + ".enc"
        guard (try? sealed.write(to: Self.dir.appendingPathComponent(name), options: [.completeFileProtection, .atomic])) != nil else { return }
        items.insert(Item(kind: kind, title: title, file: name, fileExt: ext, bytes: data.count), at: 0); persist()
    }

    func data(for item: Item) -> Data? {
        guard let key, let f = item.file, let sealed = try? Data(contentsOf: Self.dir.appendingPathComponent(f)) else { return nil }
        return try? VaultCrypto.open(sealed, with: key)
    }

    /// Decrypt a document to a temp file for viewing; the caller removes it when done.
    func tempFile(for item: Item) -> URL? {
        guard let d = data(for: item) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vault-\(item.id.uuidString.prefix(6))").appendingPathExtension(item.fileExt ?? "bin")
        try? FileManager.default.removeItem(at: url)
        return (try? d.write(to: url, options: [.completeFileProtection])) != nil ? url : nil
    }

    func delete(_ item: Item) {
        if let f = item.file { VaultCrypto.shred(Self.dir.appendingPathComponent(f)) }
        items.removeAll { $0.id == item.id }; persist()
    }

    var totalBytes: Int { items.reduce(0) { $0 + $1.bytes + $1.text.utf8.count } }
}

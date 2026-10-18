import SwiftUI
import PhotosUI
import LocalAuthentication
import UIKit

/// Secure Vault — private notes and photos behind Face ID. Files are written with full iOS file
/// protection (encrypted at rest, this device only) and the vault re-locks the moment you leave.
struct VaultItem: Identifiable, Codable {
    let id: UUID
    var kind: String        // "note" or "photo"
    var title: String
    var text: String
    var file: String?       // photo filename inside the vault folder
    var date: Date
}

@MainActor
final class VaultStore: ObservableObject {
    @Published var items: [VaultItem] = []
    private let dir: URL
    private let index: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("Vault", isDirectory: true)
        index = dir.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
    }

    func load() {
        guard let data = try? Data(contentsOf: index), let list = try? JSONDecoder().decode([VaultItem].self, from: data) else { items = []; return }
        items = list.sorted { $0.date > $1.date }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: index, options: [.completeFileProtection, .atomic]) }
    }

    func addNote(title: String, text: String) {
        items.insert(VaultItem(id: UUID(), kind: "note", title: title.isEmpty ? "Note" : title, text: text, file: nil, date: Date()), at: 0)
        persist()
    }

    func addPhoto(_ data: Data) {
        let name = "\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(name)
        guard (try? data.write(to: url, options: [.completeFileProtection, .atomic])) != nil else { return }
        items.insert(VaultItem(id: UUID(), kind: "photo", title: "Photo", text: "", file: name, date: Date()), at: 0)
        persist()
    }

    func image(for item: VaultItem) -> UIImage? {
        guard let file = item.file, let data = try? Data(contentsOf: dir.appendingPathComponent(file)) else { return nil }
        return UIImage(data: data)
    }

    func delete(_ item: VaultItem) {
        if let file = item.file { try? FileManager.default.removeItem(at: dir.appendingPathComponent(file)) }
        items.removeAll { $0.id == item.id }
        persist()
    }
}

struct SecureVaultView: View {
    @StateObject private var store = VaultStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var errorText: String?
    @State private var noteTitle = ""
    @State private var noteText = ""
    @State private var showNote = false
    @State private var photoItem: PhotosPickerItem?
    @State private var viewing: VaultItem?

    var body: some View {
        ToolPage(title: "Secure Vault", subtitle: "Private notes and photos, locked behind Face ID.") {
            if unlocked {
                unlockedBody
            } else {
                lockedBody
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { unlocked = false } }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) { store.addPhoto(data); HandyHaptics.success() }
            }
        }
        .sheet(item: $viewing) { item in
            if let img = store.image(for: item) {
                Image(uiImage: img).resizable().scaledToFit().ignoresSafeArea().background(Color.black)
            } else {
                Text("Couldn't open this photo.").padding()
            }
        }
    }

    private var lockedBody: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack {
                Circle().fill(HandyColor.accentSoft).frame(width: 72, height: 72)
                Image(systemName: "lock.fill").font(.system(size: 30)).foregroundStyle(HandyColor.accent)
            }.padding(.top, HandySpacing.s32)
            Text("Locked").font(HandyFont.title)
            Text("Your notes and photos here are encrypted and open only to you.")
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { unlock() } label: { Label("Unlock with Face ID", systemImage: "faceid").frame(maxWidth: .infinity) }.primaryButton()
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HandySpacing.s8)
    }

    private var unlockedBody: some View {
        VStack(spacing: HandySpacing.s12) {
            HStack(spacing: HandySpacing.s12) {
                Button { showNote = true } label: { Label("Add note", systemImage: "square.and.pencil").frame(maxWidth: .infinity) }.secondaryButton()
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Add photo", systemImage: "photo.badge.plus").frame(maxWidth: .infinity) }.secondaryButton()
            }

            if showNote {
                VStack(spacing: HandySpacing.s8) {
                    TextField("Title", text: $noteTitle)
                        .padding(HandySpacing.s12)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    TextEditor(text: $noteText).frame(minHeight: 110).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    HStack {
                        Button("Save note") { store.addNote(title: noteTitle, text: noteText); noteTitle = ""; noteText = ""; showNote = false; HandyHaptics.success() }.compactButton()
                            .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty && noteTitle.isEmpty)
                        Button("Cancel") { showNote = false; noteTitle = ""; noteText = "" }.textButton()
                        Spacer()
                    }
                }.cardStyle(padding: HandySpacing.s12)
            }

            if store.items.isEmpty {
                EmptyState(icon: "lock.open.fill", line: "Nothing here yet", sub: "Add a private note or photo — only you can open it.")
            } else {
                ForEach(store.items) { item in
                    vaultRow(item)
                }
            }
        }
    }

    private func vaultRow(_ item: VaultItem) -> some View {
        HStack(spacing: HandySpacing.s12) {
            if item.kind == "photo" {
                if let img = store.image(for: item) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous))
                } else {
                    Image(systemName: "photo").frame(width: 52, height: 52)
                }
            } else {
                ZStack { RoundedRectangle(cornerRadius: HandyRadius.small).fill(HandyColor.accentSoft).frame(width: 52, height: 52)
                    Image(systemName: "note.text").foregroundStyle(HandyColor.accent) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(HandyFont.bodyStrong).lineLimit(1)
                Text(item.kind == "photo" ? item.date.formatted(date: .abbreviated, time: .shortened) : item.text)
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
            }
            Spacer()
            Button { store.delete(item); HandyHaptics.light() } label: { Image(systemName: "trash").foregroundStyle(HandyColor.danger) }
                .accessibilityLabel("Delete")
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { if item.kind == "photo" { viewing = item } }
    }

    private func unlock() {
        errorText = nil
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use passcode"
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your vault") { ok, _ in
                DispatchQueue.main.async {
                    if ok { unlocked = true; store.load(); HandyHaptics.success() }
                    else { errorText = "Couldn't unlock. Try again." }
                }
            }
        } else {
            // No passcode set on the device — nothing to authenticate against. Be honest.
            errorText = "Set a device passcode (Settings › Face ID & Passcode) to protect your vault."
        }
    }
}

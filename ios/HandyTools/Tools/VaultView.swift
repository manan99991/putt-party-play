import SwiftUI
import PhotosUI
import Photos
import QuickLook
import UniformTypeIdentifiers

/// Vault — notes, secrets (PINs, door codes, Wi‑Fi passwords), photos and documents, each encrypted
/// with a key only Face ID can release. Take a photo straight into the vault so it never touches
/// the camera roll; move a photo in and delete the original; copy a secret and the clipboard clears
/// itself after 30 seconds. Locks the moment you leave.
struct VaultView: View {
    @StateObject private var vault = VaultStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var adding: VaultStore.Item.Kind?
    @State private var title = ""
    @State private var body_ = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var moveOriginal = false
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var viewing: VaultStore.Item?
    @State private var previewURL: URL?
    @State private var revealed: Set<UUID> = []
    @State private var toast: String?
    @State private var thumbs: [UUID: UIImage] = [:]
    @State private var loadingThumbs: Set<UUID> = []
    @State private var unlocking = false

    var body: some View {
        ToolPage(title: "Vault", subtitle: "Notes, secrets, photos and documents — encrypted, opened only by your face or passcode.") {
            HowTo("vault", [
                "Set it up with Face ID so only you can open it.",
                "Add private notes and photos; they are encrypted on your phone.",
                "Lock it when you are done — nothing syncs off the device.",
            ])
            if vault.unlocked { unlockedBody } else { lockedBody }
            if let toast { Text(toast).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
        }
        .onChange(of: scenePhase) { _, p in if p != .active { vault.lock(); thumbs = [:]; revealed = [] } }
        .onChange(of: photoItem) { _, item in importPhoto(item) }
        .fullScreenCover(isPresented: $showCamera) { VaultCamera { data in showCamera = false; if let data { vault.addBlob(data, kind: .photo, title: "Photo", ext: "jpg"); HandyHaptics.success() } }.ignoresSafeArea() }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { res in
            if case .success(let url) = res {
                let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let d = try? Data(contentsOf: url) { vault.addBlob(d, kind: .document, title: url.lastPathComponent, ext: url.pathExtension); HandyHaptics.success() }
            }
        }
        .sheet(item: $viewing) { item in
            if item.kind == .photo, let d = vault.data(for: item), let img = UIImage(data: d) {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: img).resizable().scaledToFit()
                    ShareLink(item: JPEGFile(data: d), preview: SharePreview(item.title)) { Image(systemName: "square.and.arrow.up").padding(10).background(.ultraThinMaterial, in: Circle()) }.padding()
                }
            } else if let url = previewURL {
                QuickLookSheet(url: url).onDisappear { try? FileManager.default.removeItem(at: url); previewURL = nil }
            } else { Text("Couldn't open this item.").padding() }
        }
    }

    // MARK: locked

    private var lockedBody: some View {
        VStack(spacing: HandySpacing.s16) {
            ZStack { Circle().fill(HandyColor.accentSoft).frame(width: 72, height: 72); Image(systemName: "lock.fill").font(.system(size: 30)).foregroundStyle(HandyColor.accent) }.padding(.top, HandySpacing.s32)
            Text("Locked").font(HandyFont.title)
            Text("Everything in here is encrypted with a key that lives only in this phone's Secure Enclave-protected keychain and is released by Face ID or your passcode.")
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button {
                guard !unlocking else { return }
                unlocking = true
                Task { await vault.unlock(); unlocking = false }
            } label: {
                HStack { if unlocking { ProgressView().tint(.white) }; Label("Unlock", systemImage: "faceid") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(unlocking)
            if let e = vault.errorText { Text(e).font(HandyFont.caption).foregroundStyle(HandyColor.danger).multilineTextAlignment(.center) }
        }.frame(maxWidth: .infinity)
    }

    // MARK: unlocked

    private var unlockedBody: some View {
        VStack(spacing: HandySpacing.s12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: HandySpacing.s8), GridItem(.flexible(), spacing: HandySpacing.s8), GridItem(.flexible(), spacing: HandySpacing.s8)], spacing: HandySpacing.s8) {
                addButton(.note, "Note", "square.and.pencil"); addButton(.secret, "Secret", "key.fill")
                Button { showCamera = true } label: { VStack(spacing: 4) { Image(systemName: "camera.fill"); Text("Camera").font(HandyFont.micro) }.frame(maxWidth: .infinity, minHeight: 56) }.secondaryButton()
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) { VStack(spacing: 4) { Image(systemName: "photo.badge.plus"); Text("Photo").font(HandyFont.micro) }.frame(maxWidth: .infinity, minHeight: 56) }.secondaryButton()
                Button { showFiles = true } label: { VStack(spacing: 4) { Image(systemName: "doc.badge.plus"); Text("File").font(HandyFont.micro) }.frame(maxWidth: .infinity, minHeight: 56) }.secondaryButton()
            }
            Toggle(isOn: $moveOriginal) { Text("When adding from Photos, delete the original").font(HandyFont.caption) }.tint(HandyColor.accent)

            if let kind = adding { composer(kind) }

            if vault.items.isEmpty { EmptyState(icon: "lock.open.fill", line: "Nothing here yet", sub: "Add a note, a secret, a photo straight from the camera, or a document.") }
            ForEach(vault.items) { item in row(item) }

            HStack {
                Text("\(vault.items.count) item\(vault.items.count == 1 ? "" : "s") · \(SizeTarget.format(vault.totalBytes))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                Button { vault.lock(); thumbs = [:]; revealed = [] } label: { Label("Lock now", systemImage: "lock.fill") }.compactButton()
            }
            Text("Camera photos never touch the camera roll or iCloud. Copied secrets leave the clipboard after 30 s. Deleting shreds the file. Lost passcode = lost vault — there is no recovery, by design.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func addButton(_ k: VaultStore.Item.Kind, _ label: String, _ icon: String) -> some View {
        Button { adding = adding == k ? nil : k; title = ""; body_ = "" } label: { VStack(spacing: 4) { Image(systemName: icon); Text(label).font(HandyFont.micro) }.frame(maxWidth: .infinity, minHeight: 56) }.secondaryButton()
    }

    private func composer(_ kind: VaultStore.Item.Kind) -> some View {
        VStack(spacing: HandySpacing.s8) {
            TextField(kind == .secret ? "What is it? (Wi‑Fi at mum's, garage code…)" : "Title", text: $title)
                .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            if kind == .secret {
                TextField("The secret itself", text: $body_).textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(.body, design: .monospaced))
                    .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            } else {
                TextEditor(text: $body_).frame(minHeight: 110).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            }
            HStack {
                Button(kind == .secret ? "Save secret" : "Save note") {
                    if kind == .secret { vault.addSecret(title: title, value: body_) } else { vault.addNote(title: title, text: body_) }
                    adding = nil; title = ""; body_ = ""; HandyHaptics.success()
                }.compactButton().disabled(body_.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { adding = nil }.textButton()
                Spacer()
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func row(_ item: VaultStore.Item) -> some View {
        HStack(spacing: HandySpacing.s12) {
            ZStack {
                RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous).fill(HandyColor.accentSoft).frame(width: 52, height: 52)
                if item.kind == .photo, let t = thumb(item) { Image(uiImage: t).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: HandyRadius.small, style: .continuous)) }
                else { Image(systemName: item.kind == .note ? "note.text" : item.kind == .secret ? "key.fill" : item.kind == .photo ? "photo" : "doc.fill").foregroundStyle(HandyColor.accent) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(HandyFont.bodyStrong).lineLimit(1)
                switch item.kind {
                case .secret: Text(revealed.contains(item.id) ? item.text : String(repeating: "•", count: max(6, min(14, item.text.count)))).font(.system(.caption, design: .monospaced)).foregroundStyle(HandyColor.textSecondary)
                case .note: Text(item.text).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                default: Text("\(item.date.formatted(date: .abbreviated, time: .shortened)) · \(SizeTarget.format(item.bytes))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Spacer()
            if item.kind == .secret {
                Button { if revealed.contains(item.id) { revealed.remove(item.id) } else { revealed.insert(item.id) } } label: { Image(systemName: revealed.contains(item.id) ? "eye.slash" : "eye") }.buttonStyle(.plain).foregroundStyle(HandyColor.textSecondary)
                Button { copySecret(item.text) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).foregroundStyle(HandyColor.accent)
            }
            Menu {
                if item.kind == .note { Button { UIPasteboard.general.string = item.text; toast = "Copied" } label: { Label("Copy", systemImage: "doc.on.doc") } }
                if item.kind == .document || item.kind == .photo, let d = vault.data(for: item) { ShareLink(item: TextFileOrData(data: d, ext: item.fileExt ?? "jpg"), preview: SharePreview(item.title)) { Label("Export", systemImage: "square.and.arrow.up") } }
                Button(role: .destructive) { vault.delete(item); thumbs[item.id] = nil; HandyHaptics.light() } label: { Label("Delete (shred)", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)).foregroundStyle(HandyColor.textSecondary) }
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { open(item) }
    }

    private func thumb(_ item: VaultStore.Item) -> UIImage? {
        if let t = thumbs[item.id] { return t }
        // Decrypt + resize OFF the main thread — doing it inline during list layout re-decrypted every
        // uncached photo on the main thread while scrolling. The Task defers all state changes past this
        // render, so there's no "modifying state during update", and the row fills in when ready.
        Task { @MainActor in
            guard thumbs[item.id] == nil, !loadingThumbs.contains(item.id) else { return }
            loadingThumbs.insert(item.id)
            let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let d = vault.data(for: item), let i = UIImage(data: d)?.resized(maxDimension: 160) else { return nil }
                return i
            }.value
            if let img { thumbs[item.id] = img }
            loadingThumbs.remove(item.id)
        }
        return nil
    }

    private func open(_ item: VaultStore.Item) {
        switch item.kind {
        case .photo: viewing = item
        case .document: previewURL = vault.tempFile(for: item); if previewURL != nil { viewing = item }
        case .secret: if revealed.contains(item.id) { revealed.remove(item.id) } else { revealed.insert(item.id) }
        case .note: UIPasteboard.general.string = item.text; toast = "Note copied"
        }
    }

    private func copySecret(_ s: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: s]], options: [.expirationDate: Date().addingTimeInterval(30), .localOnly: true])
        toast = "Copied — clears from the clipboard in 30 s"; HandyHaptics.success()
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run { vault.addBlob(data, kind: .photo, title: "Photo", ext: "jpg"); HandyHaptics.success(); photoItem = nil }
            if moveOriginal, let id = item.itemIdentifier {
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                guard status == .authorized else { await MainActor.run { toast = "Saved to the vault. To delete originals, allow full Photos access in Settings." }; return }
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets) }
                await MainActor.run { toast = "Moved into the vault — original deleted from Photos (it sits in Recently Deleted for 30 days)." }
            }
        }
    }
}

/// Camera that hands back JPEG data without ever writing to the camera roll.
private struct VaultCamera: UIViewControllerRepresentable {
    let done: (Data?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (Data?) -> Void
        init(done: @escaping (Data?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = (info[.originalImage] as? UIImage)?.normalizedUp()
            done(img?.jpegData(compressionQuality: 0.92))
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

private struct QuickLookSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController { let c = QLPreviewController(); c.dataSource = context.coordinator; return c }
    func updateUIViewController(_ c: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(url: url) }
    final class Coord: NSObject, QLPreviewControllerDataSource {
        let url: URL; init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

/// Export any vault blob with its original extension.
struct TextFileOrData: Transferable {
    let data: Data
    let ext: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("vault-export-\(UUID().uuidString.prefix(6))").appendingPathExtension(item.ext)
            try item.data.write(to: url)
            return SentTransferredFile(url)
        }
    }
}

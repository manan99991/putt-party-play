import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Song Info & Cover — rename a song's title, artist and album and give it cover art, so it shows up
/// properly in Music, Files, car stereos and players. MP3 tags are rewritten without touching the audio;
/// M4A is re-wrapped with no quality loss; WAV/AIFF are saved as M4A (they can't carry tags) and the
/// screen says so up front. A "how it will look" card previews the result before Save or Share.
struct AudioTagsView: View {
    @State private var sourceURL: URL?
    @State private var fileName = "Audio"
    @State private var tags = AudioTags.Tags()
    @State private var artPick: PhotosPickerItem?
    @State private var working = false
    @State private var resultURL: URL?
    @State private var resultTags = AudioTags.Tags()
    @State private var errorText: String?
    @State private var showFiles = false

    var body: some View {
        ToolPage(title: "Song Info & Cover",
                 subtitle: "Set a song's title, artist, album and cover art.",
                 working: working) {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                if sourceURL == nil { pickCard }
                else if let url = resultURL { result(url) }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio]) { res in
            if case .success(let url) = res { load(url) }
        }
        .handoff("audiotags") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
        .onChange(of: artPick) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                let jpeg = data.flatMap { UIImage(data: $0) }.flatMap { AudioTags.coverJPEG(from: $0) }
                await MainActor.run {
                    if let jpeg { tags.artwork = jpeg } else { errorText = "Couldn't use that photo — try another." }
                    artPick = nil
                }
            }
        }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "music.note.list").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a song or recording to name it properly and give it cover art."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a file"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
        .frame(maxWidth: .infinity)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            nowPlaying(tags)
            PhotosPicker(selection: $artPick, matching: .images) {
                Label(tags.artwork == nil ? L("Add cover art") : L("Change cover art"), systemImage: "photo").frame(maxWidth: .infinity)
            }.secondaryButton()
            if tags.artwork != nil {
                Button(L("Remove cover art")) { tags.artwork = nil }.textButton().font(HandyFont.caption)
            }
            field("Title", $tags.title)
            field("Artist", $tags.artist)
            field("Album", $tags.album)
            if let src = sourceURL, AudioTags.route(for: src) == .convert {
                Label(L("This file type can't hold song info, so Tenzy saves a tagged M4A copy — it plays everywhere."),
                      systemImage: "info.circle")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button { run() } label: {
                Label(L("Save song info"), systemImage: "checkmark").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working)
            if working { ToolProgressBar(label: "Saving…") }
            Button(L("Choose a different file")) { reset() }.textButton().font(HandyFont.caption)
                .frame(maxWidth: .infinity)
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s4) {
            Text(L(label)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            TextField(L(label), text: text).textFieldStyle(.handy)
        }
    }

    /// How the song will look in a player.
    private func nowPlaying(_ t: AudioTags.Tags) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Group {
                if let d = t.artwork, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        HandyColor.accent.opacity(0.15)
                        Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(HandyColor.accent)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).contentShape(Rectangle())
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title.isEmpty ? fileName : t.title).font(HandyFont.bodyStrong).lineLimit(1)
                Text(t.artist.isEmpty ? L("Unknown artist") : t.artist).font(HandyFont.caption)
                    .foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                if !t.album.isEmpty {
                    Text(t.album).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s8) {
            Label(L("Saved — this is what players will show:"), systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            nowPlaying(resultTags)
            AudioPlayBar(url: url)
            KeepShare(url, tool: "Audio tags")
            Button(L("Keep editing")) { resultURL = nil }.textButton().font(HandyFont.caption)
        }
    }

    // MARK: - Actions

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let local = FileManager.default.temporaryDirectory
            .appendingPathComponent("atag-\(UUID().uuidString.prefix(6)).\(url.pathExtension.isEmpty ? "audio" : url.pathExtension)")
        guard (try? FileManager.default.copyItem(at: url, to: local)) != nil else {
            errorText = "Couldn't open that file."; return
        }
        sourceURL = local
        fileName = url.deletingPathExtension().lastPathComponent
        resultURL = nil; errorText = nil; tags = AudioTags.Tags()
        Task {
            var t = await AudioTags.read(local)
            if t.title.isEmpty { t.title = url.deletingPathExtension().lastPathComponent }
            await MainActor.run { tags = t }
        }
    }

    private func reset() {
        sourceURL = nil; tags = AudioTags.Tags(); resultURL = nil; errorText = nil
    }

    private func run() {
        guard let src = sourceURL else { return }
        working = true; errorText = nil
        let t = tags
        let base = (t.title.isEmpty ? fileName : t.title).components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        Task {
            let outcome = await AudioTags.write(src, tags: t)
            var back = AudioTags.Tags()
            if case .success(let u) = outcome { back = await AudioTags.read(u) }   // verify the REAL file
            await MainActor.run {
                working = false
                switch outcome {
                case .success(let tmp):
                    let named = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(String(base.prefix(60))).\(tmp.pathExtension)")
                    try? FileManager.default.removeItem(at: named)
                    resultURL = (try? FileManager.default.moveItem(at: tmp, to: named)) != nil ? named : tmp
                    resultTags = back
                    HandyHaptics.success()
                case .failure(let f):
                    errorText = f.message
                }
            }
        }
    }
}

import SwiftUI
import AVKit

/// Movie Trailer (26 Nov): pick or film a few clips and photos, name the film, change the narrator's three lines if you
/// like, and Tenzy makes a half-minute trailer — title cards, a deep narrator, slow motion, a montage that builds, the
/// title on a huge hit and "Coming soon". Watch it, then keep it, share it or post it.
struct TrailerView: View {
    @State private var pieces: [ClipPiece] = []
    @State private var title = ""
    @State private var lines = Trailer.defaultLines
    @State private var working = false
    @State private var progress = 0.0
    @State private var result: URL?
    @State private var player = AVPlayer()
    @State private var errorText: String?
    @State private var runTask: Task<Void, Never>?

    var body: some View {
        ToolPage(title: "Movie Trailer", subtitle: "Your clips as a trailer, with a narrator and a score.", working: working) {
            if let result {
                VideoPlayer(player: player).aspectRatio(9.0 / 16.0, contentMode: .fit).frame(maxHeight: 480).frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).accessibilityIdentifier("trailer-result")
                    .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: result)); player.play() }
                KeepShare([.file(result)], lead: .share, tool: "Movie Trailer")
                Button { ToolHandoff.shared.put(.video(result), for: "post"); NotificationCenter.default.post(name: .openTool, object: "post") } label: {
                    Label(L("Post it"), systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("trailer-post")
                Button { self.result = nil; player.pause() } label: { Label(L("Change the title or lines"), systemImage: "pencil").frame(maxWidth: .infinity) }
                    .textButton()
            } else {
                ClipsPicker(pieces: $pieces, prefix: "trailer")
                if !pieces.isEmpty {
                    VStack(alignment: .leading, spacing: HandySpacing.s8) {
                        Text(L("The film's name")).font(HandyFont.cardTitle)
                        TextField(L("The Adventure"), text: $title).textFieldStyle(.handy).accessibilityIdentifier("trailer-title")
                    }
                    VStack(alignment: .leading, spacing: HandySpacing.s8) {
                        HStack {
                            Text(L("What the narrator says")).font(HandyFont.cardTitle).lineLimit(1)
                            Spacer()
                            if lines != Trailer.defaultLines {
                                Button(L("Reset")) { lines = Trailer.defaultLines }.textButton().font(HandyFont.caption)
                            }
                        }
                        ForEach(lines.indices, id: \.self) { i in
                            TextField(Trailer.defaultLines[i], text: $lines[i]).textFieldStyle(.handy).accessibilityIdentifier("trailer-line-\(i + 1)")
                        }
                    }
                    Button { make() } label: { Label(L("Make my trailer"), systemImage: "film.stack").frame(maxWidth: .infinity) }
                        .primaryButton().disabled(working).accessibilityIdentifier("trailer-make")
                    if working {
                        ToolProgressBar(value: progress > 0 ? progress : nil, label: "Making your trailer…")
                        Button(L("Stop")) { runTask?.cancel() }.textButton().frame(maxWidth: .infinity)
                    }
                }
            }
            if let errorText { Text(L(errorText)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .handoff("trailer") { p in if case .video(let u) = p { Task { await add([u]) } } }
        .task {
            if Launch.uitest, Launch.sample, pieces.isEmpty {
                let a = await SampleAssets.movie(seconds: 4), b = await SampleAssets.movie(seconds: 3, size: CGSize(width: 360, height: 640))
                await add([a, b].compactMap { $0 })
            }
        }
        .onDisappear { player.pause() }
    }

    private func add(_ urls: [URL]) async {
        let new = await ClipPiece.make(urls)
        await MainActor.run { pieces.append(contentsOf: new) }
    }

    private func make() {
        working = true; progress = 0; errorText = nil
        let urls = pieces.map(\.url), name = title, said = lines
        runTask = Task {
            let out = await Trailer.make(urls, title: name, lines: said) { p in Task { @MainActor in progress = p } }
            await MainActor.run {
                working = false
                if Task.isCancelled { errorText = "Stopped."; return }
                guard let out else {
                    errorText = "Couldn't make the trailer — try other clips."
                    if Launch.uitest, let why = BeatReel.lastProblem { errorText = (errorText ?? "") + " [\(why)]" }   // for the test's report
                    return
                }
                result = out; HandyHaptics.success()
            }
        }
    }
}

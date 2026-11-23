import SwiftUI
import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers

/// "Add music": every song on this phone that can go into a video, ready to tap — the music you've already brought
/// into Tenzy first, then the Music app's songs — with a ▶ to hear each one, a search, and "Browse all files" pinned
/// at the bottom for anything else (Files, iCloud Drive, Downloads). Says plainly why streamed Apple Music songs
/// aren't listed.
struct MusicPickerSheet: View {
    var onPick: (MusicTrack.Song) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mine: [MusicTrack.Song] = []
    @State private var library: [MusicTrack.Song] = []
    @State private var locked = 0
    @State private var access = MusicTrack.libraryAccess
    @State private var loading = true
    @State private var search = ""
    @State private var browsing = false
    @State private var playing: String?
    @State private var player = AVPlayer()
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                if let problem {
                    Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
                }
                if !filtered(mine).isEmpty {
                    Section { ForEach(filtered(mine)) { row($0) } } header: { Text(L("Your music in Tenzy")) }
                }
                Section {
                    libraryRows
                } header: {
                    Text(L("Songs on this phone"))
                } footer: {
                    if locked > 0 {
                        Text("\(locked) \(L("songs from Apple Music are copy-protected by Apple, so no app can put them in a video. Songs you bought or added from your computer work."))")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(HandyColor.bg)
            .searchable(text: $search, prompt: Text(L("Search songs")))
            .navigationTitle(L("Add music"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close")) { player.pause(); dismiss() }.accessibilityIdentifier("music-close")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button { browsing = true } label: {
                        Label(L("Browse all files"), systemImage: "folder").frame(maxWidth: .infinity)
                    }.primaryButton().accessibilityIdentifier("music-browse")
                    Text(L("MP3, WAV, M4A, AAC or AIFF — from Files, iCloud Drive or Downloads."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
                .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s8)
                .background(.ultraThinMaterial)
            }
            .fileImporter(isPresented: $browsing, allowedContentTypes: MusicTrack.fileTypes) { r in
                guard case .success(let u) = r else { return }
                Task {
                    guard let kept = MusicTrack.keep(u) else { problem = "That file couldn't be opened — try another."; return }
                    let (t, a, s) = await MusicTrack.describe(kept)
                    guard s >= 1 else { try? FileManager.default.removeItem(at: kept); problem = "That file has no sound Tenzy can read — try another."; return }
                    choose(MusicTrack.Song(id: "file-\(kept.path)", title: t, artist: a, seconds: s, url: kept))
                }
            }
        }
        .task { await load() }
        .onDisappear { player.pause() }
    }

    @ViewBuilder private var libraryRows: some View {
        switch access {
        case .notDetermined:
            Button {
                Task { access = await MusicTrack.askForLibrary(); await load() }
            } label: {
                Label(L("Show songs from the Music app"), systemImage: "music.note.list")
            }.accessibilityIdentifier("music-allow")
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Tenzy isn't allowed to see your songs. Turn on Media & Apple Music for Tenzy in Settings."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Button(L("Open Settings")) {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }.font(HandyFont.caption.weight(.semibold))
            }
        default:
            if loading {
                HStack { BusySpinner(); Text(L("Finding your songs…")).font(HandyFont.caption) }
            } else if library.isEmpty {
                Text(L("No songs on this phone can go into a video yet. Use Browse all files for a song you have as a file."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                ForEach(filtered(library)) { row($0) }
            }
        }
    }

    private func row(_ s: MusicTrack.Song) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Button { toggle(s) } label: {
                Image(systemName: playing == s.id ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30)).foregroundStyle(HandyColor.accent)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L(playing == s.id ? "Stop" : "Listen"))
            Button { choose(s) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                        Text([s.artist, SocialPost.clock(s.seconds)].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(L("Use")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("music-song")
        }
        .listRowBackground(HandyColor.surface)
    }

    private func filtered(_ list: [MusicTrack.Song]) -> [MusicTrack.Song] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q) }
    }

    private func load() async {
        loading = true
        mine = await MusicTrack.filesInTenzy()
        if MusicTrack.libraryAccess == .authorized {
            let found = await Task.detached(priority: .userInitiated) { MusicTrack.librarySongs() }.value
            library = found.usable; locked = found.locked
        }
        access = MusicTrack.libraryAccess
        loading = false
    }

    /// Hear a song from its first third, where it has usually got going.
    private func toggle(_ s: MusicTrack.Song) {
        if playing == s.id { player.pause(); playing = nil; return }
        player.replaceCurrentItem(with: AVPlayerItem(url: s.url))
        player.seek(to: CMTime(seconds: s.seconds * 0.3, preferredTimescale: 600))
        player.play()
        playing = s.id
    }

    private func choose(_ s: MusicTrack.Song) {
        player.pause(); playing = nil
        onPick(s)
        dismiss()
    }
}

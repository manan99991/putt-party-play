import SwiftUI
import AVKit

/// Settings › Help › Watch how (26 Nov): three short videos filmed from the real app on the build machine (the
/// ios-howto workflow), so they always show today's screens — say what you need, set an autorun, hand Tenzy a photo.
/// They're in the app itself, so they play with no connection. Silent, so they can be watched anywhere.
struct HowToVideo: Identifiable, Equatable {
    let id: String          // the film's file name in HowTo/, without .mp4
    let title: String
    let line: String
    let icon: String

    static let all: [HowToVideo] = [
        HowToVideo(id: "say-what-you-need", title: "Say what you need", line: "One sentence in the ask box becomes a helper that does the whole job.", icon: "text.bubble.fill"),
        HowToVideo(id: "set-an-autorun", title: "Set an autorun", line: "Switch one on, tap Test run, and see what it found for you.", icon: "clock.arrow.circlepath"),
        HowToVideo(id: "got-something", title: "Got something? Hand it over", line: "Give Tenzy a photo and pick what you want done.", icon: "tray.and.arrow.down.fill"),
    ]

    var url: URL? { Bundle.main.url(forResource: id, withExtension: "mp4", subdirectory: "HowTo") ?? Bundle.main.url(forResource: id, withExtension: "mp4") }
    /// The ones actually in this build (the row in Settings only shows when there are some).
    static var available: [HowToVideo] { all.filter { $0.url != nil } }
}

struct HowToVideosView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playing: HowToVideo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s12) {
                    Text(L("Three short videos, filmed in Tenzy itself. Tap one to watch."))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    ForEach(HowToVideo.available) { v in
                        Button { playing = v } label: {
                            HStack(spacing: HandySpacing.s12) {
                                Image(systemName: v.icon).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 48, height: 48).background(HandyColor.accent.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L(v.title)).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                    Text(L(v.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundStyle(HandyColor.accent).accessibilityHidden(true)
                            }
                            .cardStyle()
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("howto-\(v.id)")
                    }
                }
                .padding(HandySpacing.s16)
            }
            .background(HandyColor.bg)
            .navigationTitle(L("Watch how")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        }
        .fullScreenCover(item: $playing) { v in HowToPlayer(video: v) }
    }
}

/// One video, full screen, playing straight away; Done closes it.
private struct HowToPlayer: View {
    let video: HowToVideo
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let player { VideoPlayer(player: player).ignoresSafeArea(edges: .bottom) }
            Button { dismiss() } label: {
                Text(L("Done")).font(HandyFont.bodyStrong).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(minHeight: 44).background(.black.opacity(0.55), in: Capsule())
            }
            .padding(HandySpacing.s16).accessibilityIdentifier("howto-done")
        }
        .onAppear {
            guard let u = video.url else { return }
            let p = AVPlayer(url: u); p.isMuted = true; player = p; p.play()
        }
        .onDisappear { player?.pause() }
    }
}

import SwiftUI
import UIKit

extension Animate {
    /// Settings that suit the photos themselves: the post shape nearest their shape, filling the frame when they
    /// already fit it and showing the whole photo (over a soft blur) when they don't — so screenshots and tall
    /// photos are never cut in half.
    static func settings(for images: [UIImage], style: Style) -> Settings {
        var s = Settings()
        s.style = style
        guard let first = images.first, first.size.width > 0, first.size.height > 0 else { return s }
        let r = first.size.height / first.size.width
        let id = r > 1.5 ? "reels" : (r > 1.12 ? "portrait" : (r > 0.85 ? "square" : "youtube"))
        s.format = VideoFormat.preset(id) ?? s.format
        let target = s.format.size.height / s.format.size.width
        s.framing = abs(r - target) / target < 0.2 ? .fill : .fit
        return s
    }
}

/// The finish for anything that animates photos — the Animate tool's ready-made flipbook and every built tool
/// that ends in one: watch it, then try any other of the 26 styles on the same photos without starting over.
struct AnimateFinishCard: View {
    let photos: [UIImage]
    @State var style: Animate.Style
    @State var url: URL
    @State private var busy: Animate.Style?
    @State private var problem: String?
    @ObservedObject private var prog = RunProgress.shared

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            VideoFinishCard(url: url).id(url)
            Text("\(L("Style")): \(L(style.title)) — \(L(style.blurb))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Text(L("Try another animation on the same photos")).font(HandyFont.bodyStrong)
            ForEach(Animate.Style.Group.allCases) { g in
                let styles = Animate.Style.inGroup(g).filter { photos.count >= $0.minPhotos }
                if !styles.isEmpty {
                    Text(L(g.rawValue)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    HandyFlow(spacing: 8) { ForEach(styles) { chip($0) } }
                }
            }
            if busy != nil { ToolProgressBar(value: prog.fraction ?? 0, label: "Making the \(L(busy?.title ?? "")) video…") }
            if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("animate-finish")
    }

    private func chip(_ s: Animate.Style) -> some View {
        Button { change(s) } label: {
            HStack(spacing: 4) {
                if busy == s { ProgressView().controlSize(.mini) } else { Image(systemName: s.icon).font(.caption) }
                Text(L(s.title)).font(HandyFont.caption)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(style == s ? HandyColor.accent : HandyColor.surface, in: Capsule())
            .foregroundStyle(style == s ? Color.white : HandyColor.textPrimary)
        }
        .buttonStyle(.plain).disabled(busy != nil)
        .accessibilityIdentifier("animate-style-\(s.rawValue)")
    }

    private func change(_ s: Animate.Style) {
        guard s != style, busy == nil else { return }
        busy = s; problem = nil
        RunProgress.shared.begin()
        let imgs = photos, settings = Animate.settings(for: photos, style: s)
        Task {
            let out = await Task.detached(priority: .userInitiated) {
                await Animate.render(imgs, settings: settings) { p in Task { @MainActor in RunProgress.shared.set(p) } }
            }.value
            await MainActor.run {
                RunProgress.shared.end(); busy = nil
                if let out { url = out; style = s; HandyHaptics.success() } else { problem = "That style couldn't be made from these photos." }
            }
        }
    }
}

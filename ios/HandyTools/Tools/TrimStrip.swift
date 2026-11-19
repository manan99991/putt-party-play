import SwiftUI
import AVFoundation

/// The trim bar people know from Photos: a row of frames from the clip with a yellow frame you drag from either
/// end. The parts you're cutting are dimmed, the kept length is shown live, and each end can be nudged a tenth
/// of a second for a clean cut. Keeps at least half a second.
struct TrimStrip: View {
    let frames: [UIImage]
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double
    var minLength: Double = 0.5

    private let handle: CGFloat = 16

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = max(1, geo.size.width - handle * 2)
                let x0 = handle + CGFloat(start / max(duration, 0.01)) * w
                let x1 = handle + CGFloat(end / max(duration, 0.01)) * w
                ZStack(alignment: .leading) {
                    // The frames.
                    HStack(spacing: 0) {
                        ForEach(frames.indices, id: \.self) { i in
                            Image(uiImage: frames[i]).resizable().scaledToFill()
                                .frame(width: w / CGFloat(max(frames.count, 1)), height: geo.size.height).clipped()
                        }
                        if frames.isEmpty { Rectangle().fill(HandyColor.surface).frame(width: w) }
                    }
                    .offset(x: handle)
                    // What gets cut is dimmed.
                    Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, x0 - handle)).offset(x: handle)
                    Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, handle + w - x1)).offset(x: x1)
                    // The kept part, framed.
                    RoundedRectangle(cornerRadius: 6).stroke(Color.yellow, lineWidth: 3)
                        .frame(width: max(0, x1 - x0) + handle * 2, height: geo.size.height)
                        .offset(x: x0 - handle)
                        .allowsHitTesting(false)
                    grip(at: x0 - handle, height: geo.size.height, chevron: "chevron.compact.left")
                        .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                            let t = Double((g.location.x - handle) / w) * duration
                            start = min(max(0, t), end - minLength)
                        })
                        .accessibilityLabel(L("Start"))
                        .accessibilityValue(VideoClock.text(start))
                        .accessibilityAdjustableAction { dir in nudgeStart(dir == .increment ? 0.5 : -0.5) }
                    grip(at: x1, height: geo.size.height, chevron: "chevron.compact.right")
                        .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                            let t = Double((g.location.x - handle) / w) * duration
                            end = max(min(duration, t), start + minLength)
                        })
                        .accessibilityLabel(L("End"))
                        .accessibilityValue(VideoClock.text(end))
                        .accessibilityAdjustableAction { dir in nudgeEnd(dir == .increment ? 0.5 : -0.5) }
                }
            }
            .frame(height: 56)
            HStack(spacing: 6) {
                nudge("minus", { nudgeStart(-0.1) }, L("Start"))
                Text(VideoClock.text(start)).font(HandyFont.caption).monospacedDigit()
                nudge("plus", { nudgeStart(0.1) }, L("Start"))
                Spacer()
                Text("\(L("Keeps")) \(VideoClock.text(max(0, end - start)))").font(HandyFont.caption.weight(.semibold)).monospacedDigit()
                Spacer()
                nudge("minus", { nudgeEnd(-0.1) }, L("End"))
                Text(VideoClock.text(end)).font(HandyFont.caption).monospacedDigit()
                nudge("plus", { nudgeEnd(0.1) }, L("End"))
            }
            .foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func grip(at x: CGFloat, height: CGFloat, chevron: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color.yellow)
            Image(systemName: chevron).font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
        }
        .frame(width: handle, height: height)
        .contentShape(Rectangle().inset(by: -14))
        .offset(x: x)
    }

    private func nudge(_ icon: String, _ act: @escaping () -> Void, _ what: String) -> some View {
        Button(action: act) { Image(systemName: icon).font(.system(size: 12, weight: .bold)).frame(width: 30, height: 30) }
            .buttonStyle(.bordered).buttonBorderShape(.circle)
            .accessibilityLabel("\(what) \(icon == "plus" ? "+0.1s" : "−0.1s")")
    }

    private func nudgeStart(_ d: Double) { start = min(max(0, start + d), end - minLength) }
    private func nudgeEnd(_ d: Double) { end = max(min(duration, end + d), start + minLength) }
}

enum VideoClock {
    /// 0:07.3 under a minute's precision matters for a cut; 1:02.5 above.
    static func text(_ s: Double) -> String {
        let s = max(0, s)
        let m = Int(s) / 60
        return String(format: "%d:%04.1f", m, s - Double(m * 60))
    }
}

extension VideoEngine {
    /// Evenly spaced frames across the whole clip for the trim bar — small, so it's quick and light.
    static func filmstrip(_ url: URL, count: Int = 10, height: CGFloat = 112) async -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let d = (try? await asset.load(.duration).seconds) ?? 0
        guard d > 0, count > 0 else { return [] }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: height * 2, height: height)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        var out: [UIImage] = []
        for i in 0..<count {
            let t = d * (Double(i) + 0.5) / Double(count)
            if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) { out.append(UIImage(cgImage: cg)) }
        }
        return out
    }
}

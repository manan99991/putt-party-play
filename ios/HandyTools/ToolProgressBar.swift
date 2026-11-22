import SwiftUI
import UIKit
import AVFoundation
import PDFKit

/// A determinate progress bar with a short status line, for any tool doing work the user is waiting
/// on. Prefer this over a bare spinner so people can see how far a job has got and that it's moving.
///
/// - `value`: 0…1 progress. Pass `nil` for work whose length genuinely can't be measured — it shows
///   an animated indeterminate *bar* (not a dead spinner) with the label, so the UI still reads as
///   "working," not "stuck."
/// - `label`: a short human status, e.g. "Fitting photo 2 of 5…".
struct ToolProgressBar: View {
    let value: Double?
    let label: String
    var showsTime: Bool
    init(value: Double? = nil, label: String = "", showsTime: Bool = true) {
        self.value = value; self.label = label; self.showsTime = showsTime
    }
    // When the bar first appears, work has just begun — anchor the ETA to now. @State survives the
    // re-renders that update `value`, so the estimate keeps counting from the true start.
    @State private var startedAt = Date()
    @State private var spin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value {
                ProgressView(value: min(max(value, 0), 1)).tint(HandyColor.accent)
            } else {
                ProgressView().progressViewStyle(.linear).tint(HandyColor.accent)
            }
            if !label.isEmpty {
                Text(L(label)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                // An always-spinning icon, so there's visible motion the entire time the tool is working.
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(HandyColor.accent)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
                if showsTime {
                    // Shows time REMAINING when the work is measurable (not elapsed); a plain "Working…"
                    // only when the length genuinely can't be known. Re-reads the clock every second.
                    TimelineView(.periodic(from: startedAt, by: 1)) { ctx in
                        Text(status(at: ctx.date))
                            .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.25), value: value)
        .onAppear { spin = true }
    }

    private func status(at now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        if let v = value, v > 0.02 {
            let pct = Int((min(max(v, 0), 1)) * 100)
            if v >= 0.999 { return "Finishing up…" }
            if elapsed > 2 {   // wait for a little signal before estimating, so the number doesn't jump around
                let remaining = elapsed * (1 - v) / v
                return remaining < 3 ? "Almost done · \(pct)%" : "About \(clock(remaining)) left · \(pct)%"
            }
            return "\(pct)%"
        }
        return "Working…"
    }
    private func clock(_ s: TimeInterval) -> String {
        let t = Int(s.rounded())
        return t >= 60 ? String(format: "%d:%02d", t / 60, t % 60) : "\(t)s"
    }
}

/// Live progress for a running job that can't hand a value straight to the bar because it runs deep in
/// an engine (transcription above all). The engine posts a 0…1 fraction here; the running screen reads
/// it and feeds the bar, so a long recording shows a real position and an honest time-remaining.
@MainActor final class RunProgress: ObservableObject {
    static let shared = RunProgress()
    @Published var fraction: Double? = nil
    func begin() { fraction = 0.0001 }
    func set(_ f: Double) { fraction = max(fraction ?? 0, min(1, f)) }   // only ever moves forward
    func end() { fraction = nil }
}

/// A copy button that confirms it worked: the label flips to "Copied!" with a checkmark and a haptic
/// for a moment, so the user is never left wondering whether the tap did anything. Every tool that
/// offers to copy its result should use this instead of a bare copy button.
struct CopyButton: View {
    let text: String
    var title: String = "Copy"
    @State private var copied = false
    var body: some View {
        Button {
            UIPasteboard.general.string = text
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
        } label: {
            Label(copied ? "Copied!" : title, systemImage: copied ? "checkmark" : "doc.on.doc").frame(maxWidth: .infinity)
        }
        .secondaryButton()
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}

/// App-wide "Copied" confirmation. Every copy in the app goes through `Clip.copy`, which puts the text
/// on the clipboard, fires the success haptic, and flashes one shared toast pill — so a copy is never
/// silent, in any tool, whatever the button's own style. Buttons that already flip their own label to
/// "Copied" can keep doing that; this is the baseline for the rest.
@MainActor final class CopyToast: ObservableObject {
    static let shared = CopyToast()
    @Published var text: String? = nil
    @Published var icon = "checkmark.circle.fill"
    private var token = 0
    func flash(_ message: String = "Copied") { show(message, icon: "checkmark.circle.fill", seconds: 1.6) }

    /// A longer, plain-words notice in the same pill (e.g. "You're on a call…"), for things that need reading.
    func notice(_ message: String, icon: String = "info.circle.fill", seconds: Double = 5) { show(message, icon: icon, seconds: seconds) }

    private func show(_ message: String, icon: String, seconds: Double) {
        installWindow()
        self.icon = icon
        text = message
        token += 1
        let mine = token
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if self.token == mine { self.text = nil }
        }
    }

    /// The pill lives in its own see-through window above everything, so it shows over sheets and
    /// pop-ups too (a toast drawn in the main screen would be hidden behind any open sheet).
    private var window: UIWindow?
    private func installWindow() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let w = PassThroughWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.isUserInteractionEnabled = false
        let host = UIHostingController(rootView: CopyToastPill())
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.isHidden = false
        window = w
    }
}

private final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }   // never takes a tap
}

private struct CopyToastPill: View {
    @ObservedObject private var toast = CopyToast.shared
    var body: some View {
        VStack {
            Spacer()
            if let t = toast.text {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: toast.icon)
                    Text(t).font(HandyFont.bodyStrong).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: toast.text)
        .allowsHitTesting(false)
    }
}

@MainActor enum Copier {
    /// Copy text to the clipboard with a haptic and a visible "Copied" toast. Pass `note` to say
    /// exactly what was copied (e.g. "Password copied").
    static func copy(_ s: String, note: String = "Copied") {
        UIPasteboard.general.string = s
        HandyHaptics.success()
        CopyToast.shared.flash(note)
    }
}

private struct CopyToastHost: ViewModifier {
    // The pill is drawn in its own window above sheets (see CopyToast); nothing to draw here.
    func body(content: Content) -> some View { content }
}
extension View {
    /// Hosts the single app-wide "Copied" toast. Attach once, near the app root.
    func copyToastHost() -> some View { modifier(CopyToastHost()) }
}

/// Shown over a camera/sensor tool's preview when access was denied, so the user gets a clear reason
/// and a one-tap route to Settings instead of a blank black box or a silently-dead control.
/// `sub` can name the on-device fallback the tool still offers (e.g. "…or pick a photo below").
struct PermissionOffCard: View {
    var icon: String = "video.slash.fill"
    var line: String
    var sub: String? = nil
    var body: some View {
        VStack(spacing: HandySpacing.s8) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(HandyColor.textSecondary)
            Text(line).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).multilineTextAlignment(.center)
            if let sub { Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center) }
            Button { Permission.openSettings() } label: {
                Label(L("Open Settings"), systemImage: "gearshape").frame(maxWidth: .infinity)
            }.secondaryButton()
        }
        .padding(HandySpacing.s16)
    }
}

/// A horizontal strip of thumbnails for a tool's finished output files, so the user can eyeball what
/// was produced before saving or sharing. Image files show their pixels; video files show a frame.
struct OutputPreviewStrip: View {
    let urls: [URL]
    @State private var viewing: Int?
    var body: some View {
        if !urls.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                // Big enough to check each one at a glance — three across, filling the width — and every one opens
                // full screen to look closely, step through the batch, and save or share it.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HandySpacing.s8), count: urls.count == 1 ? 1 : (urls.count == 2 ? 2 : 3)),
                          spacing: HandySpacing.s8) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { i, u in
                        Button { viewing = i } label: { OutputThumb(url: u, tall: urls.count == 1) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(L("View result")) \(i + 1) \(L("of")) \(urls.count)")
                            .accessibilityIdentifier("result-thumb-\(i)")
                    }
                }
                Label(L("Tap one to see it full size"), systemImage: "hand.tap").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            .fullScreenCover(item: Binding(get: { viewing.map { ViewIndex(i: $0) } }, set: { viewing = $0?.i })) { v in
                ResultViewer(items: urls.map(ViewerItem.url), index: v.i)
            }
        }
    }
}

struct ViewIndex: Identifiable { let i: Int; var id: Int { i } }

private struct OutputThumb: View {
    let url: URL
    var tall = false
    @State private var image: UIImage?
    private var isVideo: Bool { ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) }
    var body: some View {
        // A fixed box (square, or one tall preview for a single result) with the picture filling it — the picture
        // never sets the size, so every cell lines up.
        box
            .overlay {
                ZStack {
                    HandyColor.surface
                    if let image {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: tall ? .fit : .fill)
                    } else {
                        Image(systemName: isVideo ? "film" : "doc.fill").foregroundStyle(HandyColor.textSecondary)
                    }
                    if isVideo {
                        Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundStyle(.white.opacity(0.9)).shadow(radius: 2)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            .contentShape(Rectangle())
        .task(id: url) { image = await Self.thumbnail(url) }
    }

    @ViewBuilder private var box: some View {
        if tall { Color.clear.frame(maxWidth: .infinity).frame(height: 260) }
        else { Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit) }
    }

    static func thumbnail(_ url: URL) async -> UIImage? {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff"].contains(ext) {
            return await Task.detached { UIImage(contentsOfFile: url.path)?.resized(maxDimension: 600) }.value
        }
        if ext == "pdf" {
            // The first page, so a batch of PDFs shows what's in each — not a row of file icons.
            return await Task.detached { PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 600, height: 600), for: .mediaBox) }.value
        }
        return await Task.detached { () -> UIImage? in
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 200, height: 200)
            guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) else { return nil }
            return UIImage(cgImage: cg)
        }.value
    }
}

/// The spinner for work whose length can't be measured, used everywhere a tool works: after two seconds it shows a
/// running clock beside it ("0:07"), so a slow job never looks frozen. Quick jobs look exactly as before.
struct BusySpinner: View {
    @State private var started = Date()
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
            TimelineView(.periodic(from: started, by: 1)) { ctx in
                let s = Int(ctx.date.timeIntervalSince(started))
                if s >= 2 {
                    Text(String(format: "%d:%02d", s / 60, s % 60)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        .accessibilityLabel(Text("\(s) seconds"))
                }
            }
        }
        .onAppear { started = Date() }
    }
}

/// How long a kind of work really takes on THIS phone, learned from the last runs (a running average), so a bar can
/// show an honest time left for work that can't report its own progress — text reading, an AI read.
enum WorkClock {
    private static func key(_ k: String) -> String { "workclock.\(k)" }
    /// Seconds this work usually takes here; `fallback` until it has been timed once.
    static func expected(_ k: String, fallback: Double) -> Double {
        let v = UserDefaults.standard.double(forKey: key(k))
        return v > 0 ? v : fallback
    }
    /// Records one real run: the estimate moves 40% of the way to it, so one odd run doesn't throw it off.
    static func record(_ k: String, seconds: Double) {
        guard seconds > 0.2, seconds < 600 else { return }
        let old = UserDefaults.standard.double(forKey: key(k))
        UserDefaults.standard.set(old > 0 ? old * 0.6 + seconds * 0.4 : seconds, forKey: key(k))
    }
}

/// A bar for work with no progress of its own: it fills by the time this work has taken on this phone before, shows
/// the real time left, and — if it runs long — says so honestly with a running clock instead of sitting at 99%.
struct EstimatedProgressBar: View {
    let label: String
    let expected: Double
    let startedAt: Date
    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 0.5)) { ctx in
            let elapsed = max(0, ctx.date.timeIntervalSince(startedAt))
            let v = min(0.95, elapsed / max(1, expected))
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: v).tint(HandyColor.accent)
                if !label.isEmpty {
                    Text(L(label)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Text(Self.status(elapsed: elapsed, expected: expected))
                    .font(HandyFont.micro.monospacedDigit()).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    static func status(elapsed: Double, expected: Double) -> String {
        let left = expected - elapsed
        if left > 1.5 { return "\(L("About")) \(Int(left.rounded()))s \(L("left"))" }
        if left > -2 { return L("Almost done…") }
        return "\(L("Taking a little longer than usual")) · \(Int(elapsed.rounded()))s"
    }
}

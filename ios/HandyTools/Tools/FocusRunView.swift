import SwiftUI

/// One step at a time: the step in big type, a timer against its minutes, Done / Skip / +5 min, and how far through
/// you are. For the moments a whole list is too much to look at — the follow-through other "break it down" tools
/// leave out.
struct FocusRunView: View {
    let steps: [ThinkBrain.Step]
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var started = Date()
    @State private var extra = 0
    @State private var done: Set<Int> = []
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var finished: Bool { index >= steps.count }
    private var elapsed: Int { max(0, Int(now.timeIntervalSince(started))) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                ProgressView(value: Double(min(index, steps.count)), total: Double(max(1, steps.count)))
                Text("\(min(index + 1, steps.count)) \(L("of")) \(steps.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if finished {
                    Spacer()
                    VStack(spacing: HandySpacing.s12) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(HandyColor.success)
                        Text(L("All done")).font(HandyFont.display)
                        Text("\(done.count) \(L("of")) \(steps.count) \(L("steps done. That counts."))").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
                    }.frame(maxWidth: .infinity)
                    Spacer()
                    Button { dismiss() } label: { Text(L("Close")).frame(maxWidth: .infinity) }.primaryButton()
                } else {
                    let s = steps[index]
                    Spacer()
                    Text(s.text).font(.system(size: 30, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("focus-step")
                    HStack(spacing: HandySpacing.s8) {
                        Image(systemName: "timer")
                        Text(Self.clock(elapsed)).monospacedDigit()
                        if let m = s.minutes { Text("/ \(m + extra) \(L("min"))").foregroundStyle(HandyColor.textSecondary) }
                    }
                    .font(HandyFont.title)
                    .foregroundStyle(over(s) ? HandyColor.amber : HandyColor.textPrimary)
                    if over(s) { Text(L("Taking longer is fine — keep going, or skip and come back.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    Spacer()
                    Button { done.insert(index); next() } label: { Label(L("Done"), systemImage: "checkmark").frame(maxWidth: .infinity) }.primaryButton()
                        .accessibilityIdentifier("focus-done")
                    HStack(spacing: HandySpacing.s8) {
                        Button { extra += 5 } label: { Label(L("+5 min"), systemImage: "plus").frame(maxWidth: .infinity) }.secondaryButton()
                        Button { next() } label: { Label(L("Skip"), systemImage: "forward").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                }
            }
            .padding(HandySpacing.gutter)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Close")) { dismiss() } } }
            .onReceive(tick) { now = $0 }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private func over(_ s: ThinkBrain.Step) -> Bool { s.minutes.map { elapsed > ($0 + extra) * 60 } ?? false }
    private func next() { index += 1; started = Date(); now = started; extra = 0; HandyHaptics.success() }
    static func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

import SwiftUI
import UIKit

/// The Untangle plan as a clean picture to send or save: the day's timeline, when it finishes, and the
/// encouraging line. Rendered on the phone; nothing is uploaded. (Weather is left off the picture because
/// Apple's weather data must carry its attribution wherever it is shown.)
struct UntanglePlanCard: View {
    let plan: UntanglePlan.Plan

    private var shown: [UntanglePlan.Step] { plan.steps.filter { $0.status != .skipped } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.startAt.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(.white.opacity(0.8))
                Text(L("My plan")).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("\(plan.startAt.formatted(date: .omitted, time: .shortened)) → \(plan.finishAt.formatted(date: .omitted, time: .shortened)) · \(UntanglePlanCard.duration(plan.totalMinutes))")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(LinearGradient(colors: [Color(hex: 0x5B4BDB), Color(hex: 0x8E6BF0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.prefix(14).enumerated()), id: \.element.id) { i, s in
                    HStack(alignment: .top, spacing: 12) {
                        Text(s.start.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Color(hex: 0x6B6B78))
                            .frame(width: 70, alignment: .trailing)
                        VStack(spacing: 0) {
                            Circle().fill(s.isRest ? Color(hex: 0x9AD3B0) : (s.status == .done ? Color(hex: 0x2E7D32) : Color(hex: 0x5B4BDB)))
                                .frame(width: 12, height: 12).padding(.top, 3)
                            if i < min(shown.count, 14) - 1 { Rectangle().fill(Color(hex: 0xE2E0EE)).frame(width: 2).frame(maxHeight: .infinity) }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: s.kind.icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: 0x5B4BDB))
                                Text(L(s.title)).font(.system(size: 15, weight: s.isRest ? .regular : .semibold))
                                    .foregroundStyle(Color(hex: 0x16161D)).strikethrough(s.status == .done)
                            }
                            Text(UntanglePlanCard.duration(s.totalMinutes) + (s.tripMinutes > 0 ? " · \(L("incl.")) \(UntanglePlanCard.duration(s.tripMinutes)) \(L("travel"))" : ""))
                                .font(.system(size: 12)).foregroundStyle(Color(hex: 0x6B6B78))
                            if !s.items.isEmpty {
                                Text(s.items.prefix(8).joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(Color(hex: 0x3A3A46))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.bottom, 12)
                        Spacer(minLength: 0)
                    }
                }
                if shown.count > 14 {
                    Text("+ \(shown.count - 14) \(L("more steps"))").font(.system(size: 12)).foregroundStyle(Color(hex: 0x6B6B78)).padding(.leading, 82)
                }
            }

            Text(L(plan.encouragement)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Color(hex: 0x3A3A46))
                .fixedSize(horizontal: false, vertical: true)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xF3F1FB), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                Spacer()
                Text(L("Planned with Tenzy · Untangle")).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: 0x9A98A8))
            }
        }
        .padding(22)
        .frame(width: 390)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    static func duration(_ m: Int) -> String {
        m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min")
    }

    /// The card as a picture, sharp on any screen.
    @MainActor static func image(_ plan: UntanglePlan.Plan) -> UIImage? {
        let r = ImageRenderer(content: UntanglePlanCard(plan: plan))
        r.scale = 3
        return r.uiImage
    }
}

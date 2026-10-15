import SwiftUI

/// CI screenshot preview of the alarm ring screen (launch arg: `-route ring`).
/// Mirrors the Android ring layout statically — dark background always, 96pt ultralight time,
/// label, snooze + dismiss pills. Not reachable from normal navigation.
struct AlarmRingPreviewView: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Upper 40%: time + label.
                VStack(spacing: HandySpacing.s8) {
                    Text("07:30")
                        .font(.system(size: 96, weight: .ultraLight))
                        .foregroundStyle(.white)
                    Text("Morning run")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: geo.size.width, height: geo.size.height * 0.4)
                // Lower 60%: snooze pill above dismiss pill, bottom-anchored.
                VStack(spacing: 0) {
                    Spacer()
                    Text("Snooze 9 min (2 left)")
                        .font(HandyFont.bodyStrong)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(.white.opacity(0.85), lineWidth: 1.5)
                        )
                        .padding(.bottom, HandySpacing.s16)
                    Text("Dismiss")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(HandyColor.accent, in: RoundedRectangle(cornerRadius: 36))
                }
                .frame(width: geo.size.width, height: geo.size.height * 0.6)
                .padding(.horizontal, HandySpacing.gutter)
                .padding(.bottom, HandySpacing.s24)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(HandyColor.bg)
        .preferredColorScheme(.dark) // ring is dark on Android too, in both capture modes
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
    }
}

import SwiftUI

enum OnboardingFlag {
    static var seen: Bool {
        get { UserDefaults.standard.bool(forKey: "onboarding_seen") }
        set { UserDefaults.standard.set(newValue, forKey: "onboarding_seen") }
    }
}

/// Three pages, shown once. Skip on every page. Page 1 is the brand-blue hero with the illustration set cycling.
struct OnboardingView: View {
    var startPage = 0
    let onDone: () -> Void
    let onSeePro: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let onBlue = page == 0
        ZStack {
            (onBlue ? HandyColor.accent : HandyColor.bg).ignoresSafeArea()
                .animation(.easeOut(duration: HandyMotion.slow), value: onBlue)
            TabView(selection: $page) {
                HeroPage().tag(0)
                GridPage().tag(1)
                ProPage(onSeePro: onSeePro).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            VStack {
                HStack { Spacer(); Button("Skip") { onDone() }.font(HandyFont.bodyStrong).foregroundStyle(onBlue ? .white : HandyColor.accent).padding(HandySpacing.s16) }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(onBlue ? Color.white.opacity(i == page ? 1 : 0.4) : (i == page ? HandyColor.accent : HandyColor.border))
                            .frame(width: i == page ? 10 : 8, height: i == page ? 10 : 8)
                    }
                }
                .padding(.bottom, HandySpacing.s16)
                Button(page == 0 ? "Show me" : page == 1 ? "Next" : "Start using Oddbox") {
                    if page < 2 { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { page += 1 } } else { onDone() }
                }
                .buttonStyle(OnboardingButtonStyle(onBlue: onBlue))
                .padding(.horizontal, HandySpacing.s24)
                .padding(.bottom, HandySpacing.s24)
            }
        }
        .onAppear { page = startPage }
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    let onBlue: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(HandyFont.bodyStrong)
            .foregroundStyle(onBlue ? HandyColor.accent : .white)
            .frame(maxWidth: .infinity, minHeight: HandySpacing.primaryButtonHeight)
            .background(onBlue ? Color.white : HandyColor.accent, in: Capsule())
            .scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
    }
}

private let ILLOS = ["illo_clipboard", "illo_alarm", "illo_screenshot", "illo_flashlight", "illo_sticky", "illo_qr"]

private struct HeroPage: View {
    @State private var idx = 0
    var body: some View {
        VStack(spacing: HandySpacing.s12) {
            Spacer()
            Image(ILLOS[idx]).resizable().renderingMode(.template).foregroundStyle(.white).scaledToFit().frame(width: 240, height: 240)
                .id(idx).transition(.opacity)
            Spacer()
            Text("10 tools your phone forgot.").font(HandyFont.display).foregroundStyle(.white).multilineTextAlignment(.center)
            Text("One tap each. Nothing leaves your phone.").font(HandyFont.body).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            Spacer().frame(height: 140)
        }
        .padding(.horizontal, HandySpacing.s24)
        .task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(2.2)); withAnimation(.easeInOut(duration: 0.4)) { idx = (idx + 1) % ILLOS.count } } }
    }
}

private struct GridPage: View {
    @State private var hi = 0
    private let highlight = [1, 0, 5] // Multi-Clipboard, Alarm Pro, Text from Image (in TOOLS order)
    var body: some View {
        VStack(spacing: HandySpacing.s12) {
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(TOOLS.prefix(6).enumerated()), id: \.element.id) { i, t in
                    VStack(alignment: .leading) {
                        Image(systemName: t.icon).font(.system(size: 16, weight: .medium)).foregroundStyle(HandyColor.accent)
                        Spacer()
                        Text(t.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    }
                    .padding(12).frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .background(highlight[hi] == i ? HandyColor.accentSoft : HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                    .animation(.easeInOut(duration: 0.3), value: hi)
                }
            }
            .frame(maxWidth: 300)
            Spacer()
            Text("Pick a tool. It explains itself.").font(HandyFont.display).multilineTextAlignment(.center)
            Text("Each one asks for only the permission it needs, when you turn it on.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Spacer().frame(height: 140)
        }
        .padding(.horizontal, HandySpacing.s24)
        .task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(0.9)); hi = (hi + 1) % highlight.count } }
    }
}

private struct ProPage: View {
    let onSeePro: () -> Void
    private let rows: [(String, String, String)] = [("Ads", "Yes", "None"), ("Clipboard history", "20", "Unlimited"), ("Alarms", "3", "Unlimited"), ("Price", "Free", "$9.99 a year")]
    var body: some View {
        VStack(spacing: HandySpacing.s12) {
            Spacer()
            VStack(spacing: 0) {
                HStack { Spacer(); Text("Free").frame(width: 80); Text("Pro").frame(width: 90).foregroundStyle(HandyColor.accent) }
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).padding(.bottom, HandySpacing.s8)
                ForEach(rows, id: \.0) { r in
                    Divider().overlay(HandyColor.border)
                    HStack {
                        Text(r.0).font(HandyFont.body); Spacer()
                        Text(r.1).font(.system(size: 15)).frame(width: 80)
                        Text(r.2).font(.system(size: 15, weight: .semibold)).foregroundStyle(HandyColor.accent).frame(width: 90)
                    }
                    .padding(.vertical, HandySpacing.s12)
                }
            }
            .cardStyle()
            Spacer()
            Text("Free is really free.").font(HandyFont.display).multilineTextAlignment(.center)
            Text("Pro removes ads. That's the whole pitch.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            Button("See Pro", action: onSeePro).textButton()
            Spacer().frame(height: 140)
        }
        .padding(.horizontal, HandySpacing.s24)
    }
}

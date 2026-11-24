import SwiftUI

enum OnboardingFlag {
    static var seen: Bool {
        get { UserDefaults.standard.bool(forKey: "onboarding_seen") }
        set { UserDefaults.standard.set(newValue, forKey: "onboarding_seen") }
    }
}

/// The help someone said they want on the welcome screen. Picks the Home tab Tenzy opens on first, and nothing more:
/// no tool is ever hidden (UX audit decision 4, 23 Nov).
enum WelcomeChoice: String, CaseIterable, Identifiable {
    case photos, documents, daily, car, contacts, words, business
    var id: String { rawValue }
    var title: String {
        switch self {
        case .photos: return "Photos and space"
        case .documents: return "Documents and PDFs"
        case .daily: return "Daily life and health"
        case .car: return "Car and travel"
        case .contacts: return "Contacts and phone"
        case .words: return "Words and messages"
        case .business: return "Running a small business"
        }
    }
    var icon: String {
        switch self {
        case .photos: return "photo.on.rectangle.angled"
        case .documents: return "doc.richtext.fill"
        case .daily: return "calendar"
        case .car: return "car.fill"
        case .contacts: return "person.2.fill"
        case .words: return "text.bubble.fill"
        case .business: return "briefcase.fill"
        }
    }
    /// The Home tab it opens.
    var homeTab: String {
        switch self {
        case .photos: return "photos"
        case .documents: return "pdf"
        case .daily: return "day"
        case .car, .contacts: return "phone"
        case .words: return "words"
        case .business: return "business"
        }
    }
    /// Running a small business opens the Business tab first; otherwise the first choice in the order shown decides.
    static func homeTab(for picked: Set<WelcomeChoice>) -> String? {
        picked.contains(.business) ? "business" : allCases.first(where: picked.contains)?.homeTab
    }
}

/// One welcome screen, shown once (UX audit decision 4: slideshows don't help people; a real result does). What
/// Tenzy is in one line, an optional "What do you want help with?", then Home with "See it work in 10 seconds".
/// No permission prompts here: each tool asks when it's first used.
struct OnboardingView: View {
    var startPage = 0          // kept for the screenshot routes; there is one page now
    let onDone: () -> Void
    let onSeePro: () -> Void
    @State private var picked: Set<WelcomeChoice> = []
    @State private var idx = 0
    @AppStorage("tenzy.homeTab") private var homeTab = "camera"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            HandyColor.accent.ignoresSafeArea()
            VStack(spacing: HandySpacing.s12) {
                HStack {
                    // Choose the language before reading anything: the welcome redraws in it at once.
                    LanguageMenu {
                        Label(Localizer.chosenName, systemImage: "globe").font(HandyFont.caption.weight(.semibold))
                            .foregroundStyle(HandyColor.onAccent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(HandyColor.onAccent.opacity(0.18), in: Capsule())
                    }
                    .accessibilityIdentifier("welcome-language")
                    Spacer()
                    Button(L("Skip")) { finish() }.font(HandyFont.bodyStrong).foregroundStyle(HandyColor.onAccent)
                        .frame(minHeight: 44).accessibilityIdentifier("welcome-skip")
                }
                // Short phones (an SE, a folded phone) leave the drawing out so the seven choices and Start still fit.
                if UIScreen.main.bounds.height >= 760 {
                    Image(ILLOS[idx]).resizable().renderingMode(.template).foregroundStyle(HandyColor.onAccent).scaledToFit()
                        .frame(width: 130, height: 130).id(idx).transition(.opacity).accessibilityHidden(true)
                }
                Text(L("Everyday jobs, done on your phone")).font(HandyFont.display).foregroundStyle(HandyColor.onAccent)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text(L("Sign a PDF, shrink a video, find your car, remember your pills. Nothing is uploaded."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.onAccent.opacity(0.85)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: HandySpacing.s8)
                Text(L("What do you want help with? (optional)")).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.onAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(WelcomeChoice.allCases) { c in
                        let on = picked.contains(c)
                        Button { if on { picked.remove(c) } else { picked.insert(c) } } label: {
                            HStack(spacing: 8) {
                                Image(systemName: on ? "checkmark.circle.fill" : c.icon).font(.system(size: 15, weight: .semibold)).accessibilityHidden(true)
                                Text(L(c.title)).font(.system(size: 14, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(on ? HandyColor.accent : HandyColor.onAccent)
                            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 52)
                            .background(on ? HandyColor.onAccent : HandyColor.onAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HandyColor.onAccent.opacity(on ? 0 : 0.35), lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("welcome-\(c.rawValue)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Button(L("Start")) { finish() }
                    .buttonStyle(OnboardingButtonStyle(onBlue: true))
                    .accessibilityIdentifier("welcome-start")
            }
            .padding(.horizontal, HandySpacing.s24)
            .padding(.vertical, HandySpacing.s16)
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(2.2)); withAnimation(.easeInOut(duration: 0.4)) { idx = (idx + 1) % ILLOS.count } }
        }
    }

    private func finish() {
        if picked.contains(.business) { UserDefaults.standard.set(true, forKey: HomeShelves.businessKey) }
        // What they picked opens the Tools tab at that category (24 Nov: the categories live in Tools now).
        if let t = WelcomeChoice.homeTab(for: picked) {
            homeTab = t
            UserDefaults.standard.set(t, forKey: BuilderView.jumpKey)
            NotificationCenter.default.post(name: .showTab, object: "tools")
        }
        onDone()
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    let onBlue: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(HandyFont.bodyStrong)
            .foregroundStyle(onBlue ? HandyColor.accent : HandyColor.onAccent)
            .frame(maxWidth: .infinity, minHeight: HandySpacing.primaryButtonHeight)
            .background(onBlue ? HandyColor.onAccent : HandyColor.accent, in: Capsule())
            .scaleEffect(configuration.isPressed ? HandyMotion.pressScale : 1)
    }
}

private let ILLOS = ["illo_clipboard", "illo_alarm", "illo_screenshot", "illo_flashlight", "illo_sticky", "illo_qr"]

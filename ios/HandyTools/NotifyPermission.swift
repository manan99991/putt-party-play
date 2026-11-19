import SwiftUI
import UserNotifications

/// One place for "may Tenzy send notifications?" — used by every reminder toggle, so they all behave the same:
/// ask the first time, and if the answer is no, say so plainly and open Tenzy's own notification settings.
enum NotifyPermission {
    enum State: Equatable { case allowed, notAsked, off }

    static func state() async -> State {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        switch s.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return s.alertSetting == .disabled && s.lockScreenSetting == .disabled ? .off : .allowed
        case .notDetermined: return .notAsked
        case .denied: return .off
        @unknown default: return .off
        }
    }

    /// Asks only if never asked; returns whether reminders can actually arrive.
    @discardableResult
    static func ensure() async -> Bool {
        switch await state() {
        case .allowed: return true
        case .off: return false
        case .notAsked:
            let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return ok
        }
    }

    /// Straight to Tenzy's page in Settings → Notifications (falls back to Tenzy's settings page).
    @MainActor static func openSettings() {
        let s = UIApplication.openNotificationSettingsURLString
        if let u = URL(string: s) { UIApplication.shared.open(u) }
        else if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
    }
}

/// The card a reminder toggle shows when notifications are off: what's wrong, why it matters, one button to fix it.
/// It re-checks when you come back from Settings and disappears once they're on.
struct NotificationsOffCard: View {
    @Binding var isOff: Bool
    @Environment(\.scenePhase) private var phase

    var body: some View {
        if isOff {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(L("Notifications are off for Tenzy"), systemImage: "bell.slash.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.amber)
                Text(L("So this reminder can't reach you. Tap below, turn on Allow Notifications, then come back — it switches on by itself."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                Button { NotifyPermission.openSettings() } label: {
                    Label(L("Open notification settings"), systemImage: "gear").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            .cardStyle(padding: HandySpacing.s12)
            .onChange(of: phase) { _, p in
                guard p == .active else { return }
                Task { let s = await NotifyPermission.state(); await MainActor.run { isOff = s == .off } }
            }
        }
    }
}

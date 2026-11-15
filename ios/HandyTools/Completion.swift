import SwiftUI
import UIKit
import UserNotifications

/// Carries a tool's work to completion even when the app is backgrounded, and tells the user the
/// moment it's done. Every tool routes its run through `Completion.run` so no result is ever lost to
/// a lock screen or an app switch, and the user always learns a job finished.
///
/// iOS reality: `beginBackgroundTask` buys a finite window (tens of seconds), so a very long job with
/// the app fully closed may be suspended until the user returns — it then resumes and completes. The
/// notification fires whenever the job finishes while the app isn't frontmost. Android uses a real
/// foreground service for true background completion.
enum Completion {
    private static let primed = Primed()
    final class Primed: @unchecked Sendable { var done = false; let lock = NSLock() }

    /// Ask for notification permission once, lazily, so a backgrounded result can reach the user.
    static func prime() {
        primed.lock.lock(); let already = primed.done; primed.done = true; primed.lock.unlock()
        if already { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Runs `work` off the main thread while holding a background task so it can finish off-screen,
    /// then posts a completion notification if the app isn't frontmost when it ends.
    static func run<T>(_ tool: String, ok: @escaping (T) -> Bool = { _ in true }, work: () async -> T) async -> T {
        prime()
        let id = await beginBG()
        let out = await work()
        let active = await MainActor.run { UIApplication.shared.applicationState == .active }
        if !active { notifyDone(tool, ok: ok(out)) }
        await endBG(id)
        return out
    }

    @MainActor private static func beginBG() -> UIBackgroundTaskIdentifier {
        var id: UIBackgroundTaskIdentifier = .invalid
        id = UIApplication.shared.beginBackgroundTask(withName: "tenzy-run") {
            if id != .invalid { UIApplication.shared.endBackgroundTask(id); id = .invalid }
        }
        return id
    }
    @MainActor private static func endBG(_ id: UIBackgroundTaskIdentifier) {
        if id != .invalid { UIApplication.shared.endBackgroundTask(id) }
    }

    /// Posts "<tool> is done" (or a needs-you nudge) so the user knows a job finished while away.
    static func notifyDone(_ tool: String, ok: Bool = true) {
        let c = UNMutableNotificationContent()
        c.title = ok ? "\(tool) is done" : "\(tool) couldn't finish"
        c.body = ok ? "Your result is ready in Tenzy." : "Open Tenzy to try again."
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "done-\(UUID().uuidString)", content: c, trigger: nil))
    }
}

/// One-line adoption for any tool: `.finishes(working, tool: "Fit It")`. While `working` is true it
/// holds a background task so the job can finish off-screen; when the job ends while the app isn't
/// frontmost, it posts the completion notification. Pairs with ToolProgressBar for the on-screen bar.
private struct FinishesModifier: ViewModifier {
    let working: Bool
    let tool: String
    @Environment(\.scenePhase) private var phase
    @State private var bgId: UIBackgroundTaskIdentifier = .invalid

    func body(content: Content) -> some View {
        content.onChange(of: working) { _, now in
            if now {
                if bgId == .invalid {
                    bgId = UIApplication.shared.beginBackgroundTask(withName: "tenzy-tool") {
                        if bgId != .invalid { UIApplication.shared.endBackgroundTask(bgId); bgId = .invalid }
                    }
                }
            } else {
                if bgId != .invalid { UIApplication.shared.endBackgroundTask(bgId); bgId = .invalid }
                if phase != .active { Completion.notifyDone(tool) }
            }
        }
    }
}

extension View {
    /// Keeps a tool's in-flight work alive in the background and tells the user when it finishes.
    func finishes(_ working: Bool, tool: String) -> some View { modifier(FinishesModifier(working: working, tool: tool)) }
}

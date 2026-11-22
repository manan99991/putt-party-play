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
    final class Primed: @unchecked Sendable { var done = false; var hold = false; let lock = NSLock() }

    /// While true (Home's 10-second demo on a sample), a job never asks for notifications: a first-time viewer
    /// should see the result, not a permission prompt. The ask comes with their first real job instead.
    static func holdPrompt(_ on: Bool) { primed.lock.lock(); primed.hold = on; primed.lock.unlock() }

    /// Ask for notification permission once, lazily, so a backgrounded result can reach the user.
    static func prime() {
        primed.lock.lock(); let skip = primed.done || primed.hold; if !primed.hold { primed.done = true }; primed.lock.unlock()
        if skip { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Runs `work` off the main thread while holding a background task so it can finish off-screen,
    /// then posts a completion notification if the app isn't frontmost when it ends.
    static func run<T>(_ tool: String, ok: @escaping (T) -> Bool = { _ in true }, body: @escaping @MainActor (T) -> String? = { _ in nil },
                       open: String? = nil, work: () async -> T) async -> T {
        prime()
        let id = await beginBG()
        let out = await work()
        let (active, line) = await MainActor.run { (UIApplication.shared.applicationState == .active, body(out)) }
        if !active { notifyDone(tool, ok: ok(out), body: line, open: open) }
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
    /// The body says what came out (or why it didn't), and tapping it opens where the result is — never just the app.
    static func notifyDone(_ tool: String, ok: Bool = true, body: String? = nil, open: String? = nil) {
        let c = UNMutableNotificationContent()
        c.title = L(ok ? "Done" : "Couldn't finish") + " — " + L(tool)
        c.body = body ?? L(ok ? "Tap to see your result." : "Tap to see what happened and try again.")
        c.sound = .default
        c.threadIdentifier = "results"
        if let open { c.userInfo = ["open": open] }
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
                // Tapping it opens this tool, where the result is waiting.
                if phase != .active { Completion.notifyDone(tool, open: TOOLS.first { $0.name == tool || $0.id == tool }?.id) }
            }
        }
    }
}

extension View {
    /// Keeps a tool's in-flight work alive in the background and tells the user when it finishes.
    func finishes(_ working: Bool, tool: String) -> some View { modifier(FinishesModifier(working: working, tool: tool)) }
}

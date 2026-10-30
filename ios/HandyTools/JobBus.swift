import SwiftUI
import UIKit

/// Keeps a long-running tool job (video transcode, batch convert, fit) alive and observable even when
/// the user leaves the tool screen — the progress and the finished result live here, not in the view,
/// so navigating away and coming back never loses the work. A tool drives one slot by a stable key
/// and renders from it. A UIKit background-task assertion also gives a short grace window to finish if
/// the whole app is briefly backgrounded (no background-mode entitlement, so it's finite — long jobs
/// still need the app open).
@MainActor final class JobBus: ObservableObject {
    static let shared = JobBus()

    struct State {
        var working = false
        var progress = 0.0          // 0…1 (0 while running with no measurable progress → animated bar)
        var label = ""
        var outputs: [URL] = []     // finished file(s)
        var kind = ""               // tool-defined, e.g. "video","gif","audio","image","pdf"
        var note: String?           // best-effort / partial note
        var error: String?
        var stamp = 0               // bumps on each finish, so a view can tell a new result apart
        var consumedStamp = -1      // the stamp a view has already turned into its result / charged quota
    }

    @Published private(set) var states: [String: State] = [:]

    func state(_ key: String) -> State { states[key] ?? State() }
    func isWorking(_ key: String) -> Bool { states[key]?.working == true }

    func begin(_ key: String, label: String) {
        var s = states[key] ?? State()
        s.working = true; s.progress = 0; s.label = label
        s.outputs = []; s.note = nil; s.error = nil
        states[key] = s
    }

    /// Thread-safe progress reporter for a running job — safe to call from a background queue.
    func reporter(_ key: String) -> @Sendable (Double) -> Void {
        { [weak self] f in
            Task { @MainActor in
                guard let self, var s = self.states[key], s.working else { return }
                s.progress = min(max(f, 0), 1); self.states[key] = s
            }
        }
    }

    func finish(_ key: String, outputs: [URL], kind: String, note: String?, error: String?) {
        var s = states[key] ?? State()
        s.working = false; s.progress = 1
        s.outputs = outputs; s.kind = kind; s.note = note; s.error = error
        s.stamp += 1
        states[key] = s
    }

    /// A view calls this once it has turned a finished result (stamp) into its own display / charged
    /// quota, so re-appearing doesn't do it twice.
    func markConsumed(_ key: String) {
        guard var s = states[key] else { return }
        s.consumedStamp = s.stamp; states[key] = s
    }

    func clear(_ key: String) { states[key] = nil }

    /// Run `work` as a job on this slot: marks it working, hands it a progress reporter, and stores the
    /// result on completion — all owned here, so the Task outlives the view. Wrapped in a background
    /// grace assertion. No-op if a job is already running on this key.
    func run(_ key: String, label: String,
             _ work: @escaping @Sendable (_ report: @escaping @Sendable (Double) -> Void) async -> (outputs: [URL], kind: String, note: String?, error: String?)) {
        if isWorking(key) { return }
        begin(key, label: label)
        let report = reporter(key)
        Task { @MainActor in
            let bg = UIApplication.shared.beginBackgroundTask(withName: "tenzy.\(key)")
            let r = await work(report)
            self.finish(key, outputs: r.outputs, kind: r.kind, note: r.note, error: r.error)
            if bg != .invalid { UIApplication.shared.endBackgroundTask(bg) }
        }
    }
}

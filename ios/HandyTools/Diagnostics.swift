import Foundation
import UIKit

/// On-device diagnostics for TestFlight / tester builds.
///
/// Why this exists: a frozen main thread is NOT a crash, so Apple's crash reporting and TestFlight
/// never surface it. This records what tool was on screen, how long each heavy action took, and —
/// crucially — a "UI unresponsive" marker whenever the main thread stalls past a threshold. Nothing
/// is ever uploaded: the log lives in the app's cache and only leaves the phone when the tester taps
/// "Share diagnostics" in Settings › Developer and sends it themselves.
final class Diagnostics: @unchecked Sendable {
    static let shared = Diagnostics()

    private let lock = NSLock()
    private var ring: [String] = []
    private let maxLines = 800
    private let fileURL: URL
    private var started = false

    /// The tool the user is currently looking at, so a hang or crash can be attributed.
    private var _currentTool = "Home"
    /// A lock-free mirror the signal handler can read without risking a deadlock mid-crash.
    nonisolated(unsafe) private var toolHint = "Home"
    var currentTool: String {
        get { lock.lock(); defer { lock.unlock() }; return _currentTool }
        set { lock.lock(); _currentTool = newValue; lock.unlock(); toolHint = newValue; log("open: \(newValue)") }
    }

    /// Written the instant a crash/signal fires; read once on the next launch to proactively offer the
    /// report. Its presence means "the previous session died."
    private let flagURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        fileURL = dir.appendingPathComponent("tenzy-diagnostics.log")
        flagURL = dir.appendingPathComponent("tenzy-crash.flag")
    }

    /// If the previous session ended in a crash, returns a one-line summary and clears the flag.
    /// Called once at launch so the app can offer to send the report without the user hunting for it.
    func takePendingCrash() -> String? {
        guard let s = try? String(contentsOf: flagURL, encoding: .utf8), !s.isEmpty else { return nil }
        try? FileManager.default.removeItem(at: flagURL)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func raiseFlag(_ line: String) { try? line.data(using: .utf8)?.write(to: flagURL) }

    // MARK: lifecycle

    func start() {
        lock.lock(); let already = started; started = true; lock.unlock()
        guard !already else { return }
        rollIfLarge()
        log("—— session start · \(Self.appLine()) · \(Self.deviceLine()) ——")
        installCrashHandler()
        installSignalHandlers()
        startHangMonitor()
    }

    // MARK: writing

    func log(_ message: String) {
        let line = "\(Self.stamp())  \(message)"
        lock.lock()
        ring.append(line)
        if ring.count > maxLines { ring.removeFirst(ring.count - maxLines) }
        lock.unlock()
        append(line)
    }

    /// Time a block of work and record how long it took (and if it was slow).
    @discardableResult
    func measure<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
        let t = Date()
        defer {
            let ms = Int(Date().timeIntervalSince(t) * 1000)
            log("\(name) took \(ms)ms\(ms > 1500 ? "  ⚠️ slow" : "")")
        }
        return try work()
    }

    // MARK: reading / sharing

    func reportText() -> String {
        let header = """
        Tenzy diagnostics
        \(Self.appLine())
        \(Self.deviceLine())
        Exported \(Self.stamp())

        """
        lock.lock(); let mem = ring.joined(separator: "\n"); lock.unlock()
        let disk = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let body = disk.count > mem.count ? disk : mem
        return header + body
    }

    /// Writes the report to a temp .txt for ShareLink / the share sheet.
    func reportFileURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tenzy-diagnostics.txt")
        try? reportText().data(using: .utf8)?.write(to: url)
        return url
    }

    func clear() {
        lock.lock(); ring.removeAll(); lock.unlock()
        try? FileManager.default.removeItem(at: fileURL)
        log("log cleared")
    }

    // MARK: internals

    private func append(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: fileURL) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    private func rollIfLarge() {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? nil, size > 256_000 else { return }
        // keep the last ~600 lines
        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            let kept = text.split(separator: "\n").suffix(600).joined(separator: "\n")
            try? kept.data(using: .utf8)?.write(to: fileURL)
        }
    }

    private func installCrashHandler() {
        NSSetUncaughtExceptionHandler { ex in
            let frames = ex.callStackSymbols.prefix(14).joined(separator: " | ")
            Diagnostics.shared.log("💥 CRASH \(ex.name.rawValue): \(ex.reason ?? "")  ::  \(frames)")
            Diagnostics.shared.raiseFlag("Crashed in \(Diagnostics.shared.toolHint) — \(ex.name.rawValue)")
        }
    }

    /// Catches hard aborts that NSException doesn't — above all SIGABRT, which iOS raises when an API
    /// is used without its Info.plist purpose string (the classic "crash on Allow"). We record the
    /// signal, the current tool, and a backtrace, then restore the default handler so the OS still
    /// produces its normal crash report.
    private func installSignalHandlers() {
        let signals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP]
        for s in signals {
            signal(s) { sig in
                let name = String(cString: strsignal(sig))
                let frames = Thread.callStackSymbols.prefix(16).joined(separator: " | ")
                // Lock-free: read the plain tool hint and append straight to the file.
                let line = "\(Diagnostics.stamp())  💥 SIGNAL \(sig) (\(name)) — tool: \(Diagnostics.shared.toolHint)  ::  \(frames)"
                Diagnostics.shared.append(line)
                Diagnostics.shared.raiseFlag("Crashed in \(Diagnostics.shared.toolHint) — signal \(name)")
                signal(sig, SIG_DFL)
                raise(sig)
            }
        }
    }

    /// A watchdog on a background queue that pings the main thread. If main doesn't answer within the
    /// threshold, the UI is frozen — we record one marker per freeze, attributed to the current tool.
    private func startHangMonitor() {
        if Launch.uitest { return }   // don't fire during automated screenshots / UI tests
        let threshold: DispatchTimeInterval = .milliseconds(1800)
        let q = DispatchQueue(label: "tenzy.watchdog", qos: .utility)
        q.async { [weak self] in
            while true {
                let sem = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { sem.signal() }
                if sem.wait(timeout: .now() + threshold) == .timedOut {
                    let began = Date()
                    self?.log("⚠️ UI unresponsive ≥1.8s — tool: \(self?.currentTool ?? "?")")
                    sem.wait()  // block until main recovers, so we log one marker per freeze
                    self?.log("…UI recovered after \(Int(Date().timeIntervalSince(began) + 1.8))s")
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    // MARK: context strings

    private static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm:ss.SSS"; return f.string(from: Date())
    }
    private static func appLine() -> String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "Tenzy \(v) (\(b))"
    }
    private static func deviceLine() -> String {
        "iOS \(UIDevice.current.systemVersion) · \(Self.modelID())"
    }
    private static func modelID() -> String {
        var sys = utsname(); uname(&sys)
        let id = withUnsafeBytes(of: &sys.machine) { raw -> String in
            let p = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: p)
        }
        return id
    }
}

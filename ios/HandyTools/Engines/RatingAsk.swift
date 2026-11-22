import UIKit
import StoreKit

/// Apple's own "Enjoying Tenzy?" stars, asked only at a happy moment: right after the person keeps something a tool
/// made. Never on launch, never before they've kept a few results across at least two days, never more than once in
/// a couple of months (Apple itself shows it at most three times a year). The rule is pure, so it's unit-tested.
enum RatingAsk {
    static let winsKey = "rating.wins", lastKey = "rating.lastAsked", firstKey = "rating.firstSeen"

    /// Results kept before the first ask, days since first use, and days between asks.
    static let minWins = 3, minDaysUsed = 2, daysBetween = 60

    static func shouldAsk(wins: Int, firstSeen: Date, lastAsked: Date?, now: Date) -> Bool {
        guard wins >= minWins else { return false }
        guard now.timeIntervalSince(firstSeen) >= Double(minDaysUsed) * 86_400 else { return false }
        if let last = lastAsked, now.timeIntervalSince(last) < Double(daysBetween) * 86_400 { return false }
        return true
    }

    /// A result was kept (saved to Photos or Files). Counts it, and asks for stars when the moment is right.
    @MainActor static func keptSomething(now: Date = Date()) {
        guard !Launch.uitest, !Launch.screenshots else { return }
        let d = UserDefaults.standard
        let first = d.object(forKey: firstKey) as? Date ?? { d.set(now, forKey: firstKey); return now }()
        let wins = d.integer(forKey: winsKey) + 1
        d.set(wins, forKey: winsKey)
        guard shouldAsk(wins: wins, firstSeen: first, lastAsked: d.object(forKey: lastKey) as? Date, now: now) else { return }
        d.set(now, forKey: lastKey)
        // A beat after the "Saved ✓" lands, so the person sees their result first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            AppStore.requestReview(in: scene)
        }
    }

    /// First use is remembered on launch, so "two days of use" counts from the day Tenzy was opened.
    static func noteLaunch(now: Date = Date()) {
        let d = UserDefaults.standard
        if d.object(forKey: firstKey) == nil { d.set(now, forKey: firstKey) }
    }
}

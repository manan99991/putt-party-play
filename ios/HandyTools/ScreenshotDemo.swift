import Foundation

/// Store screenshots only (`-screenshots -demo`): fills the app with a believable day — two medicines, a bill
/// coming due, watched prices, a few saved tools, the Daily Brief on — so each screen shows what it does for
/// a person, not an empty state. Never runs in a normal launch; nothing here is reachable by users.
@MainActor
enum ScreenshotDemo {
    /// Routes that open a home tab or sheet rather than pushing a tool page.
    static let homeRoutes: Set<String> = Set(["paywall", "home", "homepro", "explore", "search", "mystuff", "templates", "mytools", "describebuilt", "guidevideo"])
        .union(HomeShelves.all.map { "hometab-\($0.id)" })

    static var on: Bool { Launch.screenshots && Launch.args.contains("-demo") }

    static func seed() {
        guard on, !UserDefaults.standard.bool(forKey: "demo.seeded") else { return }
        UserDefaults.standard.set(true, forKey: "demo.seeded")

        // Medicines
        var a = Med(); a.name = "Vitamin D"; a.dose = "1 tablet"; a.note = "with breakfast"
        a.times = [TimeOfDay(hour: 8, minute: 0)]; a.supply = 24; a.perDose = 1; a.refillAt = 7
        var b = Med(); b.name = "Allergy tablet"; b.dose = "1 tablet"; b.note = ""
        b.times = [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 21, minute: 0)]
        MedStore.shared.add([a, b])

        // A bill and a letter, filed with reminders
        let cal = Calendar.current
        let store = SortedStore()
        store.save(SortedLetters.Item(kind: "Bill", title: "Electric bill", amount: "$84.20", due: cal.date(byAdding: .day, value: 3, to: Date()),
                                      summary: "Monthly electricity bill. Pay online or by phone.", remindDays: 1))
        store.save(SortedLetters.Item(kind: "Letter", title: "Car registration renewal", amount: "$62.00", due: cal.date(byAdding: .day, value: 12, to: Date()),
                                      summary: "Renew before the date to avoid a late fee.", remindDays: 3))

        // Watched prices (checked "earlier", so opening the screen doesn't fetch anything)
        let now = Date()
        func page(_ name: String, _ url: String, _ cond: NumberWatch.Condition, _ v: Double, _ last: Double, _ hoursAgo: Double) -> PageWatch {
            var p = PageWatch(name: name, url: URL(string: url)!, watch: NumberWatch(condition: cond, value: v, near: "Price"))
            p.lastValue = last; p.lastChecked = now.addingTimeInterval(-hoursAgo * 3600); p.memory = WatchMemory(last: last, armed: true, fired: nil)
            return p
        }
        PageWatcher.save([
            page("Running shoes", "https://example.com/shoes", .below, 90, 104.99, 1.5),
            page("Noise-cancelling headphones", "https://example.com/headphones", .below, 250, 279, 3),
            page("Flight to Lisbon", "https://example.com/flights", .below, 450, 512, 5),
        ])

        // A few saved tools, so My tools isn't empty
        let pick = ["safe-to-share", "letter-listen", "meeting-email", "pdf-summary"]
        let mine = ChainTemplates.all.filter { pick.contains($0.id) }
        if !mine.isEmpty { ChainStore.save(mine) }

        // Daily Brief on at 7:30
        UserDefaults.standard.set(true, forKey: "brief.on")
        UserDefaults.standard.set(7, forKey: "brief.hour"); UserDefaults.standard.set(30, forKey: "brief.minute")
    }
}

import Foundation
import Contacts
import CoreLocation

/// "For you now" (UX audit decision 2, 23 Nov): Home notices what the person's day needs from Tenzy and offers it —
/// built only from what they already set up or allowed, never a new permission. Every card says why it's there, has
/// one main action, and a Not now. The choosing is pure (unit-tested); gathering reads the phone.
enum ForYou {
    enum Kind: String, CaseIterable, Codable {
        case dose, car, bill, invoice, birthday, space, screenshots, contactsBackup
    }

    /// What one tap does.
    enum Action: Equatable {
        case open(String)                                   // a tool id
        case directions(latitude: Double, longitude: Double) // walking directions in Apple Maps
        case markTaken(medID: UUID, at: Date)
    }

    struct Card: Equatable, Identifiable {
        let id: String          // kind + what it is about, so Not now hides just this one
        let kind: Kind
        let title: String
        let why: String
        let button: String
        let action: Action
        let icon: String
        let hex: UInt32
        let priority: Int
    }

    /// Everything the cards can be made from, read on the phone.
    struct Facts {
        var now = Date()
        var doses: [(medID: UUID, name: String, at: Date, taken: Bool)] = []
        var due: [(title: String, date: Date, amount: String?)] = []
        var birthdays: [(name: String, today: Bool)] = []
        var car: (latitude: Double, longitude: Double, at: Date)?
        var meterEnds: Date?
        var freeGB: Double?
        var screenshots: Int?
        var screenshotLimit: Int?
        var contactCount: Int?          // only when Contacts access was already given
        var lastContactsBackup: Date?
        var invoices: [Invoice.Doc] = []     // made in Invoices & Quotes (Business tab)
    }

    static let maxCards = 2

    /// The cards to show, most pressing first, without the ones the person put off or turned off.
    static func cards(_ f: Facts, hidden: [String: Date] = [:], off: Set<Kind> = [], cal: Calendar = .current) -> [Card] {
        var out: [Card] = []
        let now = f.now
        // Every line is said in the app's language, with dates and times in its style (24 Nov: lines built from the
        // person's own data, like "Vitamin D at 8:00 PM", stayed English).
        let loc = Localizer.shared.locale
        let time: (Date) -> String = { $0.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(loc)) }
        let day: (Date) -> String = { $0.formatted(Date.FormatStyle().month(.abbreviated).day().locale(loc)) }
        func say(_ english: String, _ args: CVarArg...) -> String { String(format: L(english), locale: loc, arguments: args) }

        // A dose due within the hour, or missed in the last 3 hours and not marked taken.
        if let d = f.doses.filter({ !$0.taken && $0.at <= now.addingTimeInterval(3600) && $0.at >= now.addingTimeInterval(-3 * 3600) })
            .sorted(by: { $0.at < $1.at }).first {
            let late = d.at < now
            out.append(Card(id: "dose-\(d.medID)-\(Int(d.at.timeIntervalSince1970))", kind: .dose,
                            title: late ? say("%@: did you take it?", d.name) : say("%@ at %@", d.name, time(d.at)),
                            why: late ? say("It was due at %@ and isn't marked taken", time(d.at)) : L("Your next dose is coming up"),
                            button: "Mark taken", action: .markTaken(medID: d.medID, at: d.at),
                            icon: "pills.fill", hex: 0x22C55E, priority: late ? 100 : 90))
        }
        // The parked car, for 2 days.
        if let c = f.car, now.timeIntervalSince(c.at) < 48 * 3600 {
            let meterSoon = f.meterEnds.map { $0 > now && $0.timeIntervalSince(now) <= 30 * 60 } ?? false
            let meter = f.meterEnds.flatMap { $0 > now ? say("Meter ends at %@", time($0)) : nil }
            out.append(Card(id: "car-\(Int(c.at.timeIntervalSince1970))", kind: .car,
                            title: meterSoon ? "Parking ends soon" : "Your car is saved",
                            why: meter ?? say("Parked %@", c.at.formatted(Date.RelativeFormatStyle(presentation: .named).locale(loc))),
                            button: "Directions", action: .directions(latitude: c.latitude, longitude: c.longitude),
                            icon: "car.fill", hex: 0x2563EB, priority: meterSoon ? 95 : 85))
        }
        // The soonest bill due within 3 days, or overdue.
        if let b = f.due.sorted(by: { $0.date < $1.date }).first {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: b.date)).day ?? 0
            if days <= 3 {
                let when = days < 0 ? say("It was due %@", day(b.date))
                    : days == 0 ? L("It is due today") : days == 1 ? L("It is due tomorrow") : say("It is due in %d days", days)
                out.append(Card(id: "bill-\(b.title)-\(Int(b.date.timeIntervalSince1970))", kind: .bill,
                                title: b.title + (b.amount.map { ", \($0)" } ?? ""), why: when,
                                button: "Open", action: .open("sorted"), icon: "doc.text.fill", hex: 0xF97316,
                                priority: days < 0 ? 88 : 80))
            }
        }
        // The invoice a customer is most overdue on (Business tab, 23 Nov).
        if let d = f.invoices.filter({ $0.overdue(now: now, cal: cal) }).sorted(by: { ($0.due ?? now) < ($1.due ?? now) }).first {
            let due = day(d.due ?? now)
            out.append(Card(id: "invoice-\(d.id)", kind: .invoice,
                            title: d.who.isEmpty ? say("%@ isn't paid yet", d.number) : say("%@ hasn't paid yet", d.who),
                            why: say("%@ · was due %@", Invoice.money(d.total, currency: d.currency, locale: loc), due),
                            button: "See unpaid", action: .open("invoice"), icon: "doc.text.fill", hex: 0x0D9488, priority: 78))
        }
        if let p = f.birthdays.first(where: \.today) {
            out.append(Card(id: "birthday-\(p.name)-\(cal.component(.year, from: now))", kind: .birthday,
                            title: say("%@'s birthday is today", p.name), why: L("From your contacts"),
                            button: "Send wishes", action: .open("contacts"), icon: "gift.fill", hex: 0xEC4899, priority: 70))
        }
        if let g = f.freeGB, g < 5 {
            out.append(Card(id: "space", kind: .space, title: "Your phone is almost full",
                            why: say("Only %@ GB left", g < 1 ? g.formatted(.number.precision(.fractionLength(1)).locale(loc)) : String(Int(g))),
                            button: "Free up space", action: .open("cleaner"), icon: "externaldrive.fill", hex: 0x64748B, priority: 60))
        } else if let s = f.screenshots, let lim = f.screenshotLimit, s > lim {
            out.append(Card(id: "screenshots", kind: .screenshots, title: say("%d screenshots", s),
                            why: say("More than the %d you said to tell you about", lim), button: "Tidy up",
                            action: .open("cleaner"), icon: "photo.stack.fill", hex: 0x64748B, priority: 50))
        }
        // Many contacts and no backup in 90 days (or ever).
        if let n = f.contactCount, n >= 300, (f.lastContactsBackup.map { now.timeIntervalSince($0) > 90 * 86400 } ?? true) {
            let since = f.lastContactsBackup.map { say("Last backup: %@", $0.formatted(Date.FormatStyle().month(.wide).locale(loc))) } ?? L("Never backed up")
            out.append(Card(id: "contacts-backup", kind: .contactsBackup, title: say("Back up %@ contacts", n.formatted(.number.locale(loc))),
                            why: say("%@ · stays on your phone", since), button: "Back up", action: .open("contacts"),
                            icon: "person.2.fill", hex: 0x14B8A6, priority: 40))
        }
        return Array(out.filter { c in !off.contains(c.kind) && !(hidden[c.id].map { $0 > now } ?? false) }
            .sorted { $0.priority > $1.priority }.prefix(maxCards))
    }

    // MARK: - Not now / Don't suggest (on the phone)

    private static let hiddenKey = "foryou.hidden", offKey = "foryou.off"
    static var hidden: [String: Date] {
        (UserDefaults.standard.dictionary(forKey: hiddenKey) as? [String: Date]) ?? [:]
    }
    static var off: Set<Kind> {
        Set((UserDefaults.standard.stringArray(forKey: offKey) ?? []).compactMap(Kind.init(rawValue:)))
    }
    /// Not now: this card stays away for a week (a dose or a bill is a new card next time anyway).
    static func notNow(_ c: Card, now: Date = Date()) {
        var h = hidden.filter { $0.value > now }
        h[c.id] = now.addingTimeInterval(7 * 86400)
        UserDefaults.standard.set(h, forKey: hiddenKey)
    }
    /// Don't suggest this: that kind of card never comes back (Settings can turn it on again later).
    static func turnOff(_ k: Kind) {
        UserDefaults.standard.set(Array(off.union([k]).map(\.rawValue)), forKey: offKey)
    }

    // MARK: - Gathering

    @MainActor static func gather(now: Date = Date(), cal: Calendar = .current) async -> Facts {
        // UI tests: a parked car, so the card can be seen, tapped and put away on a fresh simulator.
        if Launch.uitest, Launch.args.contains("-seedcar"), ParkStore.load() == nil {
            ParkStore.save(CLLocationCoordinate2D(latitude: 41.7508, longitude: -88.1535))
        }
        var f = Facts(now: now)
        let store = MedStore.shared
        let window = MedSchedule.today(store.meds, now: now, cal: cal)
        f.doses = window.map { ($0.med.id, $0.med.name, $0.at, store.isTaken($0.med, at: $0.at)) }
        let brief = await DailyBrief.gather(for: now, cal: cal)
        f.due = brief.due; f.birthdays = brief.birthdays
        f.screenshots = brief.screenshots; f.screenshotLimit = brief.screenshotLimit; f.freeGB = brief.freeGB
        if let c = ParkStore.load(), let at = ParkStore.date() { f.car = (c.latitude, c.longitude, at) }
        f.meterEnds = ParkingMeter.endsAt
        f.invoices = InvoiceStore.shared.docs
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            f.contactCount = await Task.detached(priority: .utility) { () -> Int? in
                let r = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                var n = 0
                do { try CNContactStore().enumerateContacts(with: r) { _, _ in n += 1 } } catch { return nil }
                return n
            }.value
            let t = UserDefaults.standard.double(forKey: "contacts.backup.last")
            f.lastContactsBackup = t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        return f
    }
}

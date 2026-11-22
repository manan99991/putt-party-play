import Foundation
import UserNotifications

/// Caregiver mode for Medicine Reminders, all on the phone:
/// • "Nudge me again" — if a dose isn't marked Taken, a second alert comes 15/30/60 minutes later.
/// • A caregiver (a son, a daughter, a nurse): the follow-up alert has a "Text <name>" button, and one tap
///   sends them this week's summary ("13 of 14 doses taken").
/// • Set up someone else's medicines on your phone, then send the list; on their phone they paste it in.
/// iPhone doesn't let an app send texts by itself, so every message is one you see and send.
enum MedCare {
    static var followUpMinutes: Int { UserDefaults.standard.integer(forKey: "medcare.followup") }   // 0 = off
    static var caregiverName: String { UserDefaults.standard.string(forKey: "medcare.name") ?? "" }
    static var caregiverPhone: String { UserDefaults.standard.string(forKey: "medcare.phone") ?? "" }
    static let textAction = "MED_TEXT"
    static let prefix = "medfu-"
    static let maxFollowUps = 6

    static func followUpID(_ medID: UUID, _ at: Date) -> String { "\(prefix)\(medID.uuidString)-\(Int(at.timeIntervalSince1970))" }

    /// Which doses get a follow-up: today's and tomorrow's not yet taken, whose follow-up time is still ahead.
    static func followUps(_ meds: [Med], taken: (Med, Date) -> Bool, minutes: Int, now: Date = Date(), cal: Calendar = .current) -> [(med: Med, dose: Date, at: Date)] {
        guard minutes > 0 else { return [] }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        let doses = MedSchedule.today(meds, now: now, cal: cal) + MedSchedule.today(meds, now: tomorrow, cal: cal)
        return doses.compactMap { d in
            let at = d.at.addingTimeInterval(Double(minutes * 60))
            return at > now && !taken(d.med, d.at) ? (d.med, d.at, at) : nil
        }.sorted { $0.at < $1.at }.prefix(maxFollowUps).map { $0 }
    }

    static func followUpMessage(_ m: Med, dose: Date, caregiver: String) -> (title: String, body: String) {
        let when = dose.formatted(date: .omitted, time: .shortened)
        return ("Did you take your \(m.name)?", "It was due at \(when). Tap Taken ✓ if you have\(caregiver.isEmpty ? "." : ", or let \(caregiver) know.")")
    }

    /// "This week: 13 of 14 doses taken (93%). Missed: Metformin Tue 8 PM."
    static func weekSummary(taken: Int, due: Int, missed: [String], person: String = "") -> String {
        guard due > 0 else { return "No doses were due this week." }
        let pct = Int((Double(taken) / Double(due) * 100).rounded())
        var s = "\(person.isEmpty ? "This week" : "\(person) this week"): \(taken) of \(due) doses taken (\(pct)%)."
        if !missed.isEmpty { s += " Missed: " + missed.prefix(4).joined(separator: ", ") + (missed.count > 4 ? " and \(missed.count - 4) more." : ".") }
        return s + " — from Tenzy Medicine Reminders"
    }

    /// The text a caregiver gets: always something useful — how the week went (or that nothing was due yet), today's
    /// doses and whether each is taken, and the medicines with their times. Pure.
    static func update(to name: String, meds: [Med], taken: Int, due: Int, missed: [String],
                       today: [(name: String, at: Date, taken: Bool)]) -> String {
        var lines: [String] = []
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        lines.append(first.isEmpty ? "My medicines — an update from Tenzy:" : "Hi \(first) — my medicines, from Tenzy:")
        if due > 0 {
            let pct = Int((Double(taken) / Double(due) * 100).rounded())
            var w = "This week: \(taken) of \(due) doses taken (\(pct)%)."
            if !missed.isEmpty { w += " Missed: " + missed.prefix(4).joined(separator: ", ") + (missed.count > 4 ? " and \(missed.count - 4) more." : ".") }
            lines.append(w)
        } else {
            lines.append("Reminders are set up — nothing was due yet this week.")
        }
        if !today.isEmpty {
            lines.append("Today: " + today.map { "\($0.name) \($0.at.formatted(date: .omitted, time: .shortened)) \($0.taken ? "✓ taken" : "not yet")" }.joined(separator: ", ") + ".")
        }
        let active = meds.filter { !$0.paused }
        if !active.isEmpty {
            lines.append("My medicines:\n" + active.map { "• \($0.name) — \(MedSchedule.summary($0))" }.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n")
    }

    /// The text from the missed-dose alert's "Text <name>" button.
    static func missedNote(_ med: String, due: Date?, to name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        let when = due.map { " (due \($0.formatted(date: .omitted, time: .shortened)))" } ?? ""
        return "\(first.isEmpty ? "Hi" : "Hi \(first)") — my \(med)\(when) isn't marked taken yet. Just letting you know."
    }

    /// What goes to someone else's phone: the list they can read, and the code Tenzy reads to set it up.
    static func shareMessage(_ meds: [Med]) -> String {
        let readable = meds.map { "• \($0.name) — \(MedSchedule.summary($0))" }.joined(separator: "\n")
        return "Your medicine reminders:\n\(readable)\n\nTo set them up: open Tenzy → Medicine Reminders → Family & caregiver → Add medicines someone sent me, after copying this whole message.\n\n\(shareText(meds))"
    }

    // MARK: a weekly nudge to send the caregiver an update
    static let weeklyID = "medcare-weekly"
    static var weeklyOn: Bool { UserDefaults.standard.bool(forKey: "medcare.weekly") }
    static func setWeekly(_ on: Bool, name: String) async {
        UserDefaults.standard.set(on, forKey: "medcare.weekly")
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyID])
        guard on else { return }
        let c = UNMutableNotificationContent()
        c.title = name.isEmpty ? "Send this week's medicine update" : "Send \(name) this week's medicine update"
        c.body = "One tap in Tenzy writes it for you — how many doses were taken and any that were missed."
        c.sound = .default
        c.userInfo = ["open": "medreminder"]
        var when = DateComponents(); when.weekday = 1; when.hour = 18; when.minute = 0
        try? await center.add(UNNotificationRequest(identifier: weeklyID, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }

    static func smsURL(_ phone: String, body: String) -> URL? {
        let p = phone.filter { $0.isNumber || $0 == "+" }
        guard !p.isEmpty, let b = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "sms:\(p)&body=\(b)")
    }

    // MARK: sharing a medicine list to another phone

    static let sharePrefix = "tenzy-meds:"
    /// The list as text to send (no dose log, nothing else from this phone).
    static func shareText(_ meds: [Med]) -> String {
        var clean = meds
        for i in clean.indices { clean[i].id = UUID(); clean[i].paused = false; clean[i].supply = clean[i].supply }
        let d = (try? JSONEncoder().encode(clean)) ?? Data()
        return sharePrefix + d.base64EncodedString()
    }
    /// Medicines from text someone sent, or nil if it isn't a Tenzy medicine list.
    static func imported(_ text: String) -> [Med]? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = t.range(of: sharePrefix) else { return nil }
        let b64 = t[r.upperBound...].prefix { !$0.isWhitespace }
        guard let d = Data(base64Encoded: String(b64)), let meds = try? JSONDecoder().decode([Med].self, from: d), !meds.isEmpty, meds.count <= 40 else { return nil }
        return meds.map { var m = $0; m.id = UUID(); return m }
    }

    // MARK: booking the follow-ups

    @MainActor static func refresh(_ store: MedStore, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        let wanted = followUps(store.meds, taken: { store.isTaken($0, at: $1) }, minutes: followUpMinutes, now: now)
        let name = caregiverName
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            for w in wanted {
                let msg = followUpMessage(w.med, dose: w.dose, caregiver: name)
                let c = UNMutableNotificationContent()
                c.title = msg.title; c.body = msg.body; c.sound = .default
                c.categoryIdentifier = MedSchedule.category
                c.userInfo = ["med": w.med.id.uuidString, "dose": w.dose.timeIntervalSince1970]
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: w.at)
                center.add(UNNotificationRequest(identifier: followUpID(w.med.id, w.dose), content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    static func cancel(_ medID: UUID, dose: Date) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [followUpID(medID, dose)])
    }
}

import SwiftUI
import EventKit
import EventKitUI
import Contacts
import ContactsUI

/// "Act on it" result views. A calendar or contact result does the real thing — opens the native
/// Add-to-Calendar / Save-to-Contacts sheet pre-filled — instead of dumping raw .ics / .vcf text.
/// The person sees a clean preview first (Manan's preview-before-save rule), then one tap saves it
/// straight into Apple Calendar / Contacts. Save or share stays as a secondary way out.

// MARK: - Calendar

enum ICSParse {
    struct Event { var title: String; var start: Date?; var end: Date?; var location: String; var notes: String }

    static func parse(_ ics: String) -> Event {
        func unescape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\,", with: ",")
             .replacingOccurrences(of: "\\;", with: ";").replacingOccurrences(of: "\\\\", with: "\\")
             .trimmingCharacters(in: .whitespaces)
        }
        func value(for key: String) -> String? {
            for raw in ics.split(whereSeparator: { $0 == "\r" || $0 == "\n" }) {
                let line = String(raw)
                let up = line.uppercased()
                // Match "KEY:" or "KEY;params:" — the property name ends at ':' or ';'.
                guard up.hasPrefix(key), let after = line.dropFirst(key.count).first, after == ":" || after == ";" else { continue }
                if let colon = line.firstIndex(of: ":") { return String(line[line.index(after: colon)...]) }
            }
            return nil
        }
        func date(_ s: String?) -> Date? {
            guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
            for f in ["yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
                let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = f
                df.timeZone = f.hasSuffix("'Z'") ? TimeZone(identifier: "UTC") : .current
                if let d = df.date(from: s) { return d }
            }
            return nil
        }
        return Event(title: unescape(value(for: "SUMMARY") ?? ""),
                     start: date(value(for: "DTSTART")), end: date(value(for: "DTEND")),
                     location: unescape(value(for: "LOCATION") ?? ""), notes: unescape(value(for: "DESCRIPTION") ?? ""))
    }
}

struct CalendarEventResult: View {
    let ics: String
    let shareURL: URL?
    @State private var showEdit = false

    private var ev: ICSParse.Event { ICSParse.parse(ics) }

    private var whenText: String {
        guard let s = ev.start else { return "" }
        let d = DateFormatter(); d.dateStyle = .full; d.timeStyle = .short
        let t = DateFormatter(); t.dateStyle = .none; t.timeStyle = .short
        if let e = ev.end, Calendar.current.isDate(e, inSameDayAs: s) { return "\(d.string(from: s)) – \(t.string(from: e))" }
        return d.string(from: s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ev.title.isEmpty ? "New event" : ev.title).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                if !whenText.isEmpty { Label(whenText, systemImage: "clock").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                if !ev.location.isEmpty { Label(ev.location, systemImage: "mappin.and.ellipse").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)

            Button { showEdit = true } label: { Label(L("Add to Calendar"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            if let u = shareURL { ShareLink(item: u) { Label(L("Save or share the file"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton() }
        }
        .sheet(isPresented: $showEdit) { EventEditSheet(event: ev).ignoresSafeArea() }
    }
}

struct EventEditSheet: UIViewControllerRepresentable {
    let event: ICSParse.Event
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let vc = EKEventEditViewController()
        vc.eventStore = store
        let e = EKEvent(eventStore: store)
        e.title = event.title.isEmpty ? "New event" : event.title
        let start = event.start ?? Date()
        e.startDate = start
        e.endDate = event.end ?? start.addingTimeInterval(3600)
        if !event.location.isEmpty { e.location = event.location }
        if !event.notes.isEmpty { e.notes = event.notes }
        e.calendar = store.defaultCalendarForNewEvents
        vc.event = e
        vc.editViewDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func eventEditViewController(_ c: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) { dismiss() }
    }
}

// MARK: - Contacts

struct ContactResult: View {
    let vcf: Data
    let shareURL: URL?
    @State private var showAdd = false

    private var contact: CNContact? { (try? CNContactVCardSerialization.contacts(with: vcf))?.first }

    private func lines(_ c: CNContact) -> [(String, String)] {
        var out: [(String, String)] = []
        if !c.organizationName.isEmpty { out.append(("building.2", c.organizationName)) }
        for p in c.phoneNumbers { out.append(("phone", p.value.stringValue)) }
        for e in c.emailAddresses { out.append(("envelope", e.value as String)) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let c = contact {
                let name = CNContactFormatter.string(from: c, style: .fullName) ?? ""
                VStack(alignment: .leading, spacing: 6) {
                    Text(name.isEmpty ? "New contact" : name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    ForEach(Array(lines(c).enumerated()), id: \.offset) { _, row in
                        Label(row.1, systemImage: row.0).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)

                Button { showAdd = true } label: { Label(L("Save to Contacts"), systemImage: "person.crop.circle.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            }
            if let u = shareURL { ShareLink(item: u) { Label(L("Save or share the file"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton() }
        }
        .sheet(isPresented: $showAdd) { if let c = contact { ContactAddSheet(contact: c).ignoresSafeArea() } }
    }
}

struct ContactAddSheet: UIViewControllerRepresentable {
    let contact: CNContact
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = CNContactViewController(forNewContact: contact)
        vc.contactStore = CNContactStore()
        vc.delegate = context.coordinator
        vc.allowsActions = true
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ vc: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func contactViewController(_ vc: CNContactViewController, didCompleteWith contact: CNContact?) { dismiss() }
    }
}

// MARK: - Reminders

struct RemindersResult: View {
    /// The planned task list (RoutePlan.plan output): "1. task — [Directions](…)…" lines plus a "Tip:" line.
    let planText: String
    @State private var status: String?
    @State private var busy = false

    /// Recover clean task titles: drop the "N. " prefix and any trailing markdown action links, skip the tip.
    private var titles: [String] {
        planText.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).compactMap { raw -> String? in
            var s = String(raw).trimmingCharacters(in: .whitespaces)
            if s.isEmpty || s.hasPrefix("Tip:") { return nil }
            if let r = s.range(of: #"^\d+\.\s*"#, options: .regularExpression) { s.removeSubrange(r) }
            if let dash = s.range(of: " — [") { s = String(s[..<dash.lowerBound]) }
            s = s.trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(titles.enumerated()), id: \.offset) { _, t in
                    Label(t, systemImage: "circle").font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)

            if let status { Text(status).font(HandyFont.caption).foregroundStyle(status.hasPrefix("Couldn't") ? HandyColor.amber : HandyColor.success) }

            Button { add() } label: {
                HStack { if busy { ProgressView().tint(.white) }; Label(L("Add to Reminders"), systemImage: "checklist") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(busy || titles.isEmpty)
            CopyButton(text: planText)
        }
    }

    private func add() {
        busy = true; status = nil
        Task {
            do {
                let n = try await ThinkingReminders.add(titles: titles)
                status = n == 1 ? "1 reminder added." : "\(n) reminders added."
            } catch {
                status = "Couldn't add — allow Reminders for Tenzy in Settings, then tap again."
            }
            busy = false
        }
    }
}

import SwiftUI
import UIKit
import ImageIO
import EventKit
import EventKitUI
import Contacts
import ContactsUI

// MARK: - Animated GIF preview

extension UIImage {
    /// Build a playable animated UIImage from GIF data (SwiftUI's Image shows only the first frame).
    static func animatedGIF(data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage(data: data) }
        let count = CGImageSourceGetCount(src)
        guard count > 1 else { return UIImage(data: data) }
        var frames: [UIImage] = []; var total = 0.0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            var delay = 0.1
            if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                if let d = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, d > 0 { delay = d }
                else if let d = gif[kCGImagePropertyGIFDelayTime] as? Double, d > 0 { delay = d }
            }
            total += delay
            frames.append(UIImage(cgImage: cg))
        }
        guard !frames.isEmpty else { return UIImage(data: data) }
        return UIImage.animatedImage(with: frames, duration: total)
    }
}

/// Plays an animated GIF in the result preview, so a GIF is seen before Save or share.
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        v.image = UIImage.animatedGIF(data: data)
        v.startAnimating()
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }
    func updateUIView(_ uiView: UIImageView, context: Context) {}
}

/// "Act on it" result views. A calendar or contact result does the real thing — opens the native
/// Add-to-Calendar / Save-to-Contacts sheet pre-filled — instead of dumping raw .ics / .vcf text.
/// The person sees a clean preview first (Manan's preview-before-save rule), then one tap saves it
/// straight into Apple Calendar / Contacts. Save or share stays as a secondary way out.

// MARK: - Calendar

enum ICSParse {
    struct Event { var title: String; var start: Date?; var end: Date?; var location: String; var notes: String; var url: String? = nil }

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
                     location: unescape(value(for: "LOCATION") ?? ""), notes: unescape(value(for: "DESCRIPTION") ?? ""),
                     url: value(for: "URL").map { $0.trimmingCharacters(in: .whitespaces) })
    }
}

struct CalendarEventResult: View {
    let ics: String
    let shareURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            EventCard(event: ICSParse.parse(ics), primary: true)
            if let u = shareURL { ShareLink(item: u) { Label(L("Save or share the file"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton() }
        }
    }
}

/// One event read from a poster: everything it says — title, day and time, place, prices, tickets, contact —
/// and Add to Calendar, which opens Apple's own event screen filled in, to check once and save.
struct EventCard: View {
    let event: ICSParse.Event
    var primary = false
    var added = false
    @State private var showEdit = false

    static func when(_ ev: ICSParse.Event) -> String {
        guard let s = ev.start else { return "" }
        let d = DateFormatter(); d.dateStyle = .full; d.timeStyle = .short
        let t = DateFormatter(); t.dateStyle = .none; t.timeStyle = .short
        if let e = ev.end, Calendar.current.isDate(e, inSameDayAs: s) { return "\(d.string(from: s)) – \(t.string(from: e))" }
        return d.string(from: s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                VStack(spacing: 0) {
                    Text(event.start.map { $0.formatted(.dateTime.month(.abbreviated)) }?.uppercased() ?? "—").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 2).background(HandyColor.danger)
                    Text(event.start.map { $0.formatted(.dateTime.day()) } ?? "?").font(.system(size: 22, weight: .bold)).foregroundStyle(HandyColor.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 2)
                }
                .frame(width: 52).background(HandyColor.surface).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title.isEmpty ? L("New event") : event.title).font(HandyFont.cardTitle).foregroundStyle(HandyColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !Self.when(event).isEmpty { Label(Self.when(event), systemImage: "clock").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
                    if !event.location.isEmpty { Label(event.location, systemImage: "mappin.and.ellipse").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
                    if let u = event.url.flatMap(URL.init(string:)) { Link(destination: u) { Label(u.host ?? u.absoluteString, systemImage: "link") }.font(HandyFont.caption) }
                }
            }
            if !event.notes.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(event.notes.components(separatedBy: "\n").filter { !$0.isEmpty }, id: \.self) { n in
                        Label(n, systemImage: n.range(of: #"[$€£₹]\s?\d|price|ticket"#, options: [.regularExpression, .caseInsensitive]) != nil ? "ticket" : (n.contains("@") || n.lowercased().contains("contact") ? "person.crop.circle" : "info.circle"))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if added {
                Label(L("In your calendar"), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
            } else if primary {
                Button { showEdit = true } label: { Label(L("Add to Calendar"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            } else {
                Button { showEdit = true } label: { Label(L("Add to Calendar"), systemImage: "calendar.badge.plus") }.compactButton()
            }
            Text(L("Check the date and time against the poster — you can change anything before saving.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
        .sheet(isPresented: $showEdit) { EventEditSheet(event: event).ignoresSafeArea() }
    }
}

/// Several posters at once: each event as its own card with its own Add, and Add all to put every one in the
/// calendar in one go.
struct EventsBatchResult: View {
    let events: [ICSParse.Event]
    @State private var addedAll = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text("\(events.count) \(L(events.count == 1 ? "event" : "events"))").font(HandyFont.cardTitle)
            Button { addAll() } label: {
                Label(addedAll ? L("All added to your calendar") : "\(L("Add all")) \(events.count) \(L("to Calendar"))", systemImage: addedAll ? "checkmark.circle.fill" : "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }.primaryButton().disabled(addedAll).accessibilityIdentifier("events-add-all")
            if let error { Text(L(error)).font(HandyFont.caption).foregroundStyle(HandyColor.danger).fixedSize(horizontal: false, vertical: true) }
            ForEach(Array(events.enumerated()), id: \.offset) { _, e in EventCard(event: e, added: addedAll) }
        }
    }

    private func addAll() {
        Task {
            let store = EKEventStore()
            let ok = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
            await MainActor.run {
                guard ok, let cal = store.defaultCalendarForNewEvents else {
                    error = "Tenzy can't add to your calendar yet. Allow it in Settings › Tenzy › Calendars, or add each event on its own below."
                    return
                }
                do {
                    for ev in events {
                        let e = EKEvent(eventStore: store)
                        e.title = ev.title.isEmpty ? "New event" : ev.title
                        let start = ev.start ?? Date()
                        e.startDate = start; e.endDate = ev.end ?? start.addingTimeInterval(3600)
                        if !ev.location.isEmpty { e.location = ev.location }
                        if !ev.notes.isEmpty { e.notes = ev.notes }
                        if let u = ev.url.flatMap(URL.init(string:)) { e.url = u }
                        e.calendar = cal
                        try store.save(e, span: .thisEvent, commit: false)
                    }
                    try store.commit()
                    addedAll = true; error = nil
                    HandyHaptics.success()
                } catch { self.error = "Couldn't add them all — try adding each event on its own below." }
            }
        }
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
        if let u = event.url.flatMap(URL.init(string:)) { e.url = u }
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

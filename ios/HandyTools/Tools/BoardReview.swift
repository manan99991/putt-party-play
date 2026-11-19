import SwiftUI

/// After a photo is read: everything that was on it, in the shape it had — headings and their items (done ones
/// ticked), events on their dates, who's doing what each day — to check and fix, then send where it belongs:
/// Tenzy Planner, Apple Reminders, Calendar or a spreadsheet. Nothing is "copy all text".
struct BoardReview: View {
    let photo: UIImage
    var readNow = true
    @State private var board = Understand.Board()
    @State private var reading = true
    @State private var status: String?
    @State private var bad = false
    @State private var busy = false
    @State private var zoom = false
    @State private var showPlanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if reading {
                ToolProgressBar(label: L("Reading the photo — headings, ticks, dates and names…"))
            } else if board.isEmpty {
                Label(L("Nothing readable was found. Try a straighter, closer photo in good light."), systemImage: "exclamationmark.triangle.fill")
                    .font(HandyFont.body).foregroundStyle(HandyColor.amber).cardStyle(padding: HandySpacing.s12)
            } else {
                summary
                if !board.events.isEmpty { eventsCard }
                ForEach(groups, id: \.self) { g in sectionCard(g) }
                if !board.people.isEmpty { peopleCard }
                actions
            }
        }
        .task { if readNow { await read() } }
        .sheet(isPresented: $zoom) { ZoomPhoto(image: photo) }
        .sheet(isPresented: $showPlanner) { NavigationStack { PlannerView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { showPlanner = false } } } } }
    }

    private func read() async {
        reading = true
        board = await Understand.read(photo)
        reading = false
    }

    // MARK: what was found

    private var summary: some View {
        HStack(alignment: .top, spacing: HandySpacing.s12) {
            Button { zoom = true } label: {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }.buttonStyle(.plain).accessibilityLabel(L("See the photo"))
            VStack(alignment: .leading, spacing: 4) {
                Text(headline).font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
                Label(L(board.byAI ? "Read by Apple Intelligence on your phone" : "Read by text recognition"), systemImage: board.byAI ? "sparkles" : "text.viewfinder")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                ForEach(board.notes, id: \.self) { n in Text(L(n)).font(HandyFont.micro).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var headline: String {
        var parts: [String] = []
        let open = board.tasks.filter { !$0.done }.count, done = board.tasks.count - open
        if open > 0 { parts.append("\(open) \(L(open == 1 ? "thing to do" : "things to do"))") }
        if done > 0 { parts.append("\(done) \(L("already done"))") }
        if !board.events.isEmpty { parts.append("\(board.events.count) \(L(board.events.count == 1 ? "event" : "events"))") }
        let people = Set(board.people.map(\.person)).count
        if people > 0 { parts.append("\(people) \(L(people == 1 ? "person's week" : "people's week"))") }
        return parts.joined(separator: " · ")
    }

    private var groups: [String] {
        var g: [String] = []
        for t in board.tasks where !g.contains(t.section) { g.append(t.section) }
        return g
    }

    private func sectionCard(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name.isEmpty ? L("To do") : name).font(HandyFont.bodyStrong)
            ForEach($board.tasks) { $t in
                if t.section == name {
                    HStack(spacing: 8) {
                        Button { t.done.toggle() } label: {
                            Image(systemName: t.done ? "checkmark.circle.fill" : "circle").foregroundStyle(t.done ? HandyColor.success : HandyColor.textSecondary)
                        }.buttonStyle(.plain).accessibilityLabel(L(t.done ? "Done" : "Not done"))
                        TextField(L("Task"), text: $t.text).font(HandyFont.body).strikethrough(t.done)
                            .foregroundStyle(t.include ? HandyColor.textPrimary : HandyColor.textSecondary)
                        if let d = t.due { Text(d.formatted(.dateTime.weekday(.abbreviated).day())).font(HandyFont.micro).foregroundStyle(HandyColor.accent) }
                        Button { t.include.toggle() } label: {
                            Image(systemName: t.include ? "xmark.circle" : "plus.circle").foregroundStyle(HandyColor.textSecondary)
                        }.buttonStyle(.plain).accessibilityLabel(L(t.include ? "Leave this out" : "Put it back"))
                    }
                    .opacity(t.include ? 1 : 0.45)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("Events"), systemImage: "calendar").font(HandyFont.bodyStrong)
            ForEach($board.events) { $e in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField(L("Event"), text: $e.title).font(HandyFont.body)
                        Button { e.include.toggle() } label: { Image(systemName: e.include ? "xmark.circle" : "plus.circle").foregroundStyle(HandyColor.textSecondary) }
                            .buttonStyle(.plain).accessibilityLabel(L(e.include ? "Leave this out" : "Put it back"))
                    }
                    DatePicker(L("When"), selection: Binding(get: { e.date ?? Date() }, set: { e.date = $0; e.hasTime = true }),
                               displayedComponents: e.hasTime ? DatePickerComponents([.date, .hourAndMinute]) : DatePickerComponents.date)
                        .font(HandyFont.caption)
                }
                .opacity(e.include ? 1 : 0.45)
                Divider()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var peopleCard: some View {
        let names = board.people.reduce(into: [String]()) { if !$0.contains($1.person) { $0.append($1.person) } }
        return VStack(alignment: .leading, spacing: 8) {
            Label(L("Who's doing what"), systemImage: "person.2").font(HandyFont.bodyStrong)
            ForEach(names, id: \.self) { n in
                VStack(alignment: .leading, spacing: 2) {
                    Text(n).font(HandyFont.body.weight(.semibold))
                    ForEach(board.people.filter { $0.person == n }) { p in
                        Text("\(L(p.day)) · \(p.what)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: where it goes

    private var chosen: [PlannerStore.Entry] { PlannerStore.entries(from: board, source: "Photo · " + Date().formatted(date: .abbreviated, time: .omitted)) }

    private var actions: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Where should it go?")).font(HandyFont.bodyStrong)
            Button {
                let n = PlannerStore.shared.add(chosen); HandyHaptics.success()
                status = n == 0 ? L("Already in your Planner.") : "\(n) \(L("added to Tenzy Planner."))"; bad = false
            } label: { Label(L("Add to Tenzy Planner"), systemImage: "list.bullet.rectangle").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("board-planner")
            if chosen.contains(where: { !$0.isEvent && !$0.done }) {
                Button { send(reminders: true) } label: { Label(L("Add to Reminders"), systemImage: "checklist").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(busy)
            }
            if chosen.contains(where: \.isEvent) {
                Button { send(reminders: false) } label: { Label(L("Add events to Calendar"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(busy)
            }
            ShareLink(item: XLSXFile(data: XLSXWriter.workbook(rows: sheetRows, sheetName: "Board") ?? Data()),
                      preview: SharePreview("Board.xlsx")) {
                Label(L("Open as a spreadsheet"), systemImage: "tablecells").frame(maxWidth: .infinity)
            }.secondaryButton()
            if let status {
                HStack {
                    Text(status).font(HandyFont.caption).foregroundStyle(bad ? HandyColor.amber : HandyColor.success).fixedSize(horizontal: false, vertical: true)
                    if !bad { Button(L("Open Planner")) { showPlanner = true }.textButton() }
                }
            }
        }
    }

    private var sheetRows: [[String]] {
        if !board.people.isEmpty {
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let names = board.people.reduce(into: [String]()) { if !$0.contains($1.person) { $0.append($1.person) } }
            return [["Name"] + days] + names.map { n in [n] + days.map { d in board.people.filter { $0.person == n && $0.day == d }.map(\.what).joined(separator: "; ") } }
        }
        var rows = [["List", "Item", "Done", "Date"]]
        for t in board.tasks where t.include { rows.append([t.section, t.text, t.done ? "Yes" : "", t.due.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? ""]) }
        for e in board.events where e.include { rows.append(["Events", e.title, "", e.date.map { $0.formatted(date: .abbreviated, time: e.hasTime ? .shortened : .omitted) } ?? ""]) }
        return rows
    }

    private func send(reminders: Bool) {
        busy = true
        let items = chosen
        Task {
            do {
                let n = reminders ? try await PlannerStore.toReminders(items) : try await PlannerStore.toCalendar(items)
                status = reminders ? "\(n) \(L("added to Reminders."))" : "\(n) \(L("added to Calendar."))"; bad = false
                HandyHaptics.success()
            } catch {
                status = reminders ? L("Allow Reminders for Tenzy in Settings, then tap again.") : L("Allow Calendars for Tenzy in Settings, then tap again.")
                bad = true
            }
            busy = false
        }
    }
}

private struct ZoomPhoto: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) { Image(uiImage: image).resizable().scaledToFit().frame(minWidth: 380) }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } } }
        }
    }
}

import SwiftUI
import PhotosUI

/// Tenzy Planner: snap a whiteboard, a wall calendar, a fridge list or a team schedule and it becomes a planner
/// you can tick off — Today, This week, and your lists — with a morning note of what's due, and one tap to put
/// it in Apple Reminders or Calendar.
struct PlannerView: View {
    @ObservedObject private var store = PlannerStore.shared
    private enum Tab: Int, CaseIterable { case today, week, lists
        var title: String { ["Today", "This week", "Lists"][rawValue] } }
    @State private var tab: Tab = .today
    @State private var pick: PhotosPickerItem?
    @State private var reading: PhotoBox?
    @State private var camera = false
    @AppStorage(PlannerStore.morningKey) private var morning = false
    @State private var notifOff = false

    var body: some View {
        ToolPage(title: "Planner", subtitle: "Snap a whiteboard, wall calendar, list or schedule. It becomes a planner you can tick off, with a morning note of what's due.") {
            HStack(spacing: HandySpacing.s8) {
                PhotosPicker(selection: $pick, matching: .images) { Label(L("Read a photo"), systemImage: "photo").frame(maxWidth: .infinity) }
                    .primaryButton().accessibilityIdentifier("planner-photo")
                Button { camera = true } label: { Label(L("Take one"), systemImage: "camera").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if store.entries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Works with")).font(HandyFont.bodyStrong)
                    ForEach(["A whiteboard of to-do lists — ticked items come in as done", "A wall calendar with notes and sticky notes — times become events", "A team or family week — who does what each day", "A handwritten list on paper or the fridge"], id: \.self) {
                        Label(L($0), systemImage: "checkmark").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            } else {
                Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.rawValue) { Text(L($0.title)).tag($0) } }.pickerStyle(.segmented)
                switch tab {
                case .today: todayList
                case .week: weekList
                case .lists: listsView
                }
                morningCard
            }
        }
        .onChange(of: pick) { _, item in
            Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { reading = PhotoBox(image: img) } ; pick = nil }
        }
        .sheet(item: $reading) { box in
            NavigationStack {
                ScrollView { BoardReview(photo: box.image).padding(HandySpacing.gutter) }
                    .background(Ground())
                    .navigationTitle(L("From your photo")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { reading = nil } } }
            }
        }
        .fullScreenCover(isPresented: $camera) {
            SelfieCamera(front: false) { img in camera = false; if let img { reading = PhotoBox(image: img.normalizedUp()) } }.ignoresSafeArea()
        }
    }

    private struct PhotoBox: Identifiable { let id = UUID(); let image: UIImage }

    private func row(_ e: PlannerStore.Entry, showDate: Bool = false) -> some View {
        HStack(spacing: 10) {
            Button { store.toggle(e) } label: {
                Image(systemName: e.done ? "checkmark.circle.fill" : (e.isEvent ? "calendar" : "circle"))
                    .foregroundStyle(e.done ? HandyColor.success : HandyColor.accent)
            }.buttonStyle(.plain).accessibilityLabel(L(e.done ? "Done" : "Mark done"))
            VStack(alignment: .leading, spacing: 1) {
                Text(e.text).font(HandyFont.body).strikethrough(e.done).foregroundStyle(e.done ? HandyColor.textSecondary : HandyColor.textPrimary)
                let meta = [showDate ? e.due.map { $0.formatted(.dateTime.weekday(.abbreviated).day()) } : nil,
                            e.hasTime ? e.due.map { $0.formatted(date: .omitted, time: .shortened) } : nil,
                            e.list == e.person ? nil : e.person, e.place.isEmpty ? nil : e.place].compactMap { $0 }
                if !meta.isEmpty { Text(meta.joined(separator: " · ")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            }
            Spacer(minLength: 0)
            Button { store.remove(e) } label: { Image(systemName: "trash").foregroundStyle(HandyColor.textSecondary) }
                .buttonStyle(.plain).accessibilityLabel(L("Delete"))
        }
    }

    private var todayList: some View {
        let items = store.today()
        return VStack(alignment: .leading, spacing: 8) {
            if items.isEmpty { Text(L("Nothing dated for today. Your lists are under Lists.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            ForEach(items) { row($0) }
            if !items.isEmpty { sendButtons(items) }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private var weekList: some View {
        VStack(alignment: .leading, spacing: 10) {
            let w = store.week()
            if w.isEmpty { Text(L("Nothing dated in the next 7 days.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            ForEach(Array(w.enumerated()), id: \.offset) { _, d in
                Text(d.day.formatted(.dateTime.weekday(.wide).day().month())).font(HandyFont.bodyStrong)
                ForEach(d.items) { row($0) }
            }
            if !w.isEmpty { sendButtons(w.flatMap(\.items)) }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
    }

    private var listsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(store.lists.enumerated()), id: \.offset) { _, l in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.name).font(HandyFont.bodyStrong)
                        Spacer()
                        Text("\(l.items.filter { !$0.done }.count) \(L("left"))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    ForEach(l.items) { row($0, showDate: true) }
                    sendButtons(l.items)
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
            }
        }
    }

    @State private var sendStatus: String?
    private func sendButtons(_ items: [PlannerStore.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if items.contains(where: { !$0.isEvent && !$0.done }) {
                    Button { Task { sendStatus = (try? await PlannerStore.toReminders(items)).map { "\($0) \(L("added to Reminders."))" } ?? L("Allow Reminders for Tenzy in Settings, then tap again.") } } label: {
                        Label(L("To Reminders"), systemImage: "checklist") }.compactButton()
                }
                if items.contains(where: \.isEvent) {
                    Button { Task { sendStatus = (try? await PlannerStore.toCalendar(items)).map { "\($0) \(L("added to Calendar."))" } ?? L("Allow Calendars for Tenzy in Settings, then tap again.") } } label: {
                        Label(L("To Calendar"), systemImage: "calendar.badge.plus") }.compactButton()
                }
            }
            if let sendStatus { Text(sendStatus).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
        }
    }

    private var morningCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(L("A note at 8:00 with what's due that day"), isOn: $morning).font(HandyFont.body).tint(HandyColor.accent)
                .onChange(of: morning) { _, on in
                    Task {
                        if on, !(await NotifyPermission.ensure()) { notifOff = true; morning = false; return }
                        PlannerStore.rescheduleMorning(store.entries)
                    }
                }
            if notifOff {
                Button(L("Notifications are off for Tenzy — open Settings")) { Permission.openSettings() }.textButton()
            }
            if morning {
                Button { PlannerStore.testMorning(store.entries); CopyToast.shared.flash(L("Test note in 5 seconds")) } label: { Label(L("Test run"), systemImage: "bell.badge") }.compactButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }
}

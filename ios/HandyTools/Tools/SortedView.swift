import SwiftUI
import PhotosUI

/// Sorted — snap any letter and know what to do. Point the camera at a bill, appointment card, form
/// or notice; get what it is, what you owe, and the date that matters, then add it to your calendar
/// in a tap. The scan and the thinking happen on your phone.
struct SortedView: View {
    @EnvironmentObject var store: StoreManager
    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var parsed: SortedEngine.Parsed?
    @State private var icsFile: URL?
    @State private var busy = false
    @State private var working = false
    @State private var errorText: String?
    @StateObject private var letters = SortedStore()
    @StateObject private var receiptStore = ReceiptStore()
    @State private var draft: SortedLetters.Item?          // what was read, editable before it's kept
    @State private var acts = SortedLetters.Actions()
    @State private var showScanner = false
    @State private var notifOff = false
    @State private var savedNote: String?
    @State private var testNote: String?

    private var hasText: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 }

    var body: some View {
        ToolPage(title: "Sorted", subtitle: "Snap a bill, appointment card, form or notice — get what it is, what you owe and the deadline, then add it to your calendar.", working: busy) {
            HowTo("sorted", [
                "Snap a photo of the letter, bill or card (or paste its text).",
                "Tap Make sense of it — you get what it is, the amount, and the date.",
                "Fix anything it got wrong, pick when to be reminded, and keep it in My letters — or add it to your calendar.",
            ])

            inputCard
            if busy { ToolProgressBar(label: "Reading it…") }

            if hasText {
                Button { run() } label: { HStack { if working { BusySpinner().tint(.white) }; Label(working ? "Thinking…" : "Make sense of it", systemImage: "wand.and.stars") }.frame(maxWidth: .infinity) }
                    .primaryButton().disabled(working)
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let parsed, draft != nil { resultCard(parsed) }
            if !letters.items.isEmpty { lettersList }
            if !letters.items.isEmpty { PaperworkExportCard(receipts: receiptStore) }

            if !AIEngine.isAvailable {
                LimitNote("Dates and amounts are found on every phone. The plain-English \u{201C}what it is / what to do\u{201D} line uses Apple Intelligence (iPhone 15 Pro or newer).")
            }
            Text(L("A reading aid, not official advice — always check the original document for the exact terms and deadline.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.sample, text.isEmpty { text = "City Water Utility\nAccount 55-2910\nService address: 12 Maple St\nAmount due: $84.20\nPayment due by December 15, 2026\nPlease pay by the due date to avoid a $10 late fee." } }
        .sheet(isPresented: $showScanner) {
            DocCameraSheet { pages in
                showScanner = false
                guard !pages.isEmpty else { return }
                busy = true; parsed = nil; draft = nil
                Task {
                    var all: [String] = []
                    for p in pages { all.append(await AIEngine.recognizeText(p)) }
                    await MainActor.run { busy = false; text = all.joined(separator: "\n\n"); if hasText { run() } }
                }
            }.ignoresSafeArea()
        }
        .onChange(of: draft) { _, d in icsFile = d.flatMap { SortedEngine.icsURL(SortedEngine.Parsed(kind: $0.kind, title: $0.title, amount: $0.amount, due: $0.due, summary: $0.summary)) } }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true; parsed = nil
            Task { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { let t = await AIEngine.recognizeText(img); await MainActor.run { busy = false; text = t } } else { await MainActor.run { busy = false; errorText = "Couldn't read that image." } } }
        }
    }

    private var inputCard: some View {
        VStack(spacing: HandySpacing.s8) {
            TextEditor(text: $text).frame(minHeight: 110).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) { if text.isEmpty { Text(L("Snap or paste the document…")).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
            HandyFlow(spacing: HandySpacing.s8) {
                Button { showScanner = true } label: { Label(L("Scan pages"), systemImage: "doc.viewfinder") }.compactButton()
                PhotosPicker(selection: $photoItem, matching: .images) { Label(L("Photo"), systemImage: "photo") }.compactButton()
                Button(L("Paste")) { if let s = Clipboard.text { text = s; parsed = nil } }.compactButton()
                if hasText { Button(L("Clear")) { text = ""; parsed = nil; draft = nil; errorText = nil } .textButton() }
            }
        }
    }

    private func resultCard(_ p: SortedEngine.Parsed) -> some View {
        let d = Binding(get: { draft ?? SortedLetters.Item(kind: p.kind, title: p.title, summary: p.summary) }, set: { draft = $0 })
        return VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Text(d.wrappedValue.kind.uppercased()).font(HandyFont.micro).foregroundStyle(HandyColor.accent).padding(.horizontal, 8).padding(.vertical, 3).background(HandyColor.accentSoft, in: Capsule())
                Spacer()
                Text(L("Check it, fix anything")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            TextField(L("What it is"), text: d.title).font(HandyFont.cardTitle)
            Text(d.wrappedValue.summary).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: HandySpacing.s8) {
                Image(systemName: "dollarsign.circle.fill").foregroundStyle(HandyColor.accent)
                Text(L("Amount")).foregroundStyle(HandyColor.textSecondary)
                TextField(L("None"), text: Binding(get: { d.wrappedValue.amount ?? "" }, set: { d.wrappedValue.amount = $0.isEmpty ? nil : $0 }))
                    .multilineTextAlignment(.trailing).font(HandyFont.bodyStrong)
            }
            Toggle(isOn: Binding(get: { d.wrappedValue.due != nil }, set: { d.wrappedValue.due = $0 ? (d.wrappedValue.due ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())) : nil })) {
                Label(L("There's a date to remember"), systemImage: "calendar").foregroundStyle(HandyColor.textSecondary)
            }.tint(HandyColor.accent)
            if d.wrappedValue.due != nil {
                DatePicker(L("Date"), selection: Binding(get: { d.wrappedValue.due ?? Date() }, set: { d.wrappedValue.due = $0 }), displayedComponents: .date)
                Text(L("Remind me")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: HandySpacing.s8) {
                    ForEach(Array(SortedLetters.remindChoices.enumerated()), id: \.offset) { _, c in
                        HChip(text: L(c.label), selected: d.wrappedValue.remindDays == c.days) { d.wrappedValue.remindDays = c.days; if c.days != nil { askNotify() } }
                    }
                }
                if d.wrappedValue.remindDays != nil {
                    Stepper("\(L("At")) \(TimeOfDay(hour: d.wrappedValue.remindHour, minute: 0).label)", value: d.remindHour, in: 6...21)
                    if (d.wrappedValue.remindDays ?? 0) > 0 {
                        Toggle(L("And again on the day"), isOn: Binding(get: { d.wrappedValue.alsoOnDay ?? true }, set: { d.wrappedValue.alsoOnDay = $0 }))
                            .font(HandyFont.caption).tint(HandyColor.accent)
                    }
                    if let at = SortedLetters.remindAt(d.wrappedValue) {
                        Text("\(L("You'll get:")) \u{201C}\(SortedLetters.message(d.wrappedValue, now: at).title)\u{201D} — \(at.formatted(date: .abbreviated, time: .shortened))")
                            .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                        Button {
                            let item = d.wrappedValue
                            Task {
                                guard await NotifyPermission.ensure() else { notifOff = true; return }
                                await SortedLetters.testRun(item); testNote = L("Test sent — it arrives in 5 seconds.")
                            }
                        } label: { Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity) }.secondaryButton()
                            .accessibilityIdentifier("sorted-testrun")
                        if let testNote { Text(testNote).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
                    } else {
                        Text(L("That moment has already passed, so pick a later reminder.")).font(HandyFont.micro).foregroundStyle(HandyColor.amber)
                    }
                    NotificationsOffCard(isOff: $notifOff)
                }
            }
            if !acts.isEmpty { actionsRow }
            Button { keep() } label: { Label(L("Keep it in My letters"), systemImage: "tray.and.arrow.down.fill").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("sorted-keep")
            HStack(spacing: HandySpacing.s8) {
                if let url = icsFile {
                    ShareLink(item: url) { Label(L("Add to Calendar"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.secondaryButton()
                }
                Button { let t = shareText(p); Copier.copy(t); ClipStore.add(t) } label: { Label(L("Copy"), systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let savedNote { Text(L(savedNote)).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
        }.cardStyle()
    }

    /// Call, email, open the pay or info link, copy the account number — whatever the letter printed.
    private var actionsRow: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("From the letter")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(acts.phones, id: \.self) { ph in
                    if let u = URL(string: "tel:" + ph.filter { $0.isNumber || $0 == "+" }) { Link(destination: u) { Label(ph, systemImage: "phone.fill") }.compactButton() }
                }
                ForEach(acts.emails, id: \.self) { e in
                    if let u = URL(string: "mailto:" + e) { Link(destination: u) { Label(e, systemImage: "envelope.fill") }.compactButton() }
                }
                ForEach(acts.links, id: \.self) { u in
                    Link(destination: u) { Label(u.host() ?? L("Open link"), systemImage: "safari") }.compactButton()
                }
                if let r = acts.reference {
                    Button { Copier.copy(r) } label: { Label("\(L("Copy")) \(r)", systemImage: "number") }.compactButton()
                }
            }
            if !acts.links.isEmpty {
                Text(L("Only open a payment link if you trust the sender — when in doubt, type the company's address yourself.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
    }

    /// The letters you kept: open ones by date (overdue in red), then the ones you've dealt with.
    private var lettersList: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("My letters")).font(HandyFont.cardTitle)
            let months = SortedLetters.months(letters.items)
            if !months.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(months, id: \.month) { m in
                        HStack {
                            Text(m.month.formatted(.dateTime.month(.wide).year())).font(HandyFont.caption.weight(.semibold))
                            Spacer()
                            Text("\(m.count) \(L("due"))\(m.total > 0 ? String(format: " · %.2f", m.total) : "")").font(HandyFont.caption).monospacedDigit()
                        }
                    }
                }.padding(10).background(HandyColor.accentSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityElement(children: .combine)
            }
            ForEach(SortedLetters.ordered(letters.items)) { i in
                HStack(alignment: .top, spacing: HandySpacing.s12) {
                    Button { letters.toggleDone(i) } label: {
                        Image(systemName: i.done ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(i.done ? HandyColor.success : HandyColor.textSecondary)
                    }.buttonStyle(.plain).accessibilityLabel(i.done ? L("Mark as not done") : L("Mark as done"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i.title).font(HandyFont.bodyStrong).strikethrough(i.done).foregroundStyle(i.done ? HandyColor.textSecondary : HandyColor.textPrimary)
                        HStack(spacing: 6) {
                            Text(L(i.kind)).font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                            if let a = i.amount { Text(a).font(HandyFont.micro.weight(.semibold)) }
                            if let due = i.due {
                                let late = !i.done && Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date())
                                Text(due.formatted(date: .abbreviated, time: .omitted)).font(HandyFont.micro).foregroundStyle(late ? HandyColor.danger : HandyColor.textSecondary)
                                if late { Text(L("overdue")).font(HandyFont.micro.weight(.bold)).foregroundStyle(HandyColor.danger) }
                            }
                            if i.remindDays != nil && !i.done { Image(systemName: "bell.fill").font(.system(size: 9)).foregroundStyle(HandyColor.textSecondary).accessibilityLabel(L("Reminder on")) }
                        }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(L("Open again")) { draft = i; parsed = SortedEngine.Parsed(kind: i.kind, title: i.title, amount: i.amount, due: i.due, summary: i.summary); acts = SortedLetters.Actions(); savedNote = nil }
                        Button(L("Delete"), role: .destructive) { letters.delete(i) }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(HandyColor.textSecondary) }
                        .accessibilityLabel(L("More"))
                }
                .padding(HandySpacing.s12)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            }
            Text(L("Kept on this phone only. Tick one off when it's paid or done — its reminder is cancelled.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func keep() {
        guard let d = draft else { return }
        letters.save(d)
        savedNote = d.due != nil && d.remindDays != nil && SortedLetters.remindAt(d) != nil ? "Kept, with your reminder set." : "Kept in My letters."
        HandyHaptics.success()
    }

    private func askNotify() {
        Task { let ok = await NotifyPermission.ensure(); await MainActor.run { notifOff = !ok } }
    }

    private func shareText(_ p: SortedEngine.Parsed) -> String {
        var s = "\(p.kind): \(p.title)\n\(p.summary)"
        if let a = p.amount { s += "\nAmount: \(a)" }
        if let d = p.due { s += "\nDate: \(SortedEngine.dateString(d))" }
        return s + "\n\n(Reading aid, not advice — Tenzy)"
    }

    private func run() {
        working = true; errorText = nil
        let t = text
        let basic = SortedEngine.basicParse(t)   // instant, reliable
        parsed = basic; savedNote = nil
        draft = SortedLetters.Item(kind: basic.kind, title: basic.title, amount: basic.amount, due: basic.due, summary: basic.summary, remindDays: basic.due == nil ? nil : 1)
        acts = SortedLetters.actions(in: t)
        HandyHaptics.success()
        Task { @MainActor in
            defer { working = false }
            if let refined = await SortedEngine.aiParse(t) {
                parsed = refined
                // Take the clearer reading, but never over something the person already changed.
                if var d = draft, d.title == basic.title, d.amount == basic.amount, d.due == basic.due {
                    d.kind = refined.kind; d.title = refined.title; d.summary = refined.summary
                    d.amount = refined.amount ?? d.amount; d.due = refined.due ?? d.due
                    draft = d
                }
            }
        }
    }
}

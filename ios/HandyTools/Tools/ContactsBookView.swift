import SwiftUI
import Contacts
import ContactsUI
import PhotosUI

/// Contacts Pro — every contact in one fast list: search anything, one-tap filters (no phone, no email, work,
/// home, social, birthdays, your Favorite / Emergency / Important marks), groups and accounts, then select
/// many and export (Excel or contact cards), email, save to the cloud, group, mark or delete — always
/// confirmed. Tap a person for their photo, marks, one-tap call/text/email/directions, birthday and
/// "plan a call or visit".
struct ContactsBookView: View {
    @State private var people: [ContactBook.Person] = []
    @State private var groups: [ContactBook.Group] = []
    @State private var accounts: [String] = []
    @State private var tags: [String: Set<ContactBook.Tag>] = ContactTags.load()
    @State private var loading = false
    @State private var query = ""
    @State private var filters: Set<ContactBook.Filter> = []
    @State private var group: String?
    @State private var account: String?
    @State private var selecting = false
    @State private var picked: Set<String> = []
    @State private var open: ContactBook.Person?
    @State private var exportURL: URL?
    @State private var confirmDelete = false
    @State private var showGroupPicker = false
    @State private var note: String?
    @State private var showMail: URL?
    @AppStorage("birthdays.on") private var birthdaysOn = false
    @AppStorage("birthdays.hour") private var birthdayHour = 9
    @State private var notifOff = false
    @State private var editing: ContactBook.BulkField?
    @State private var editValue = ""
    @State private var backupURL: URL?
    @State private var backupEvery = ContactBackupReminder.every
    @State private var backupNote: String?

    private var shown: [ContactBook.Person] {
        ContactBook.filtered(people, query: query, filters: filters, group: group, account: account, tags: tags)
    }
    private var chosen: [ContactBook.Person] { people.filter { picked.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            searchBar
            filterChips
            scopeRow
            if loading { HStack { ProgressView(); Text(L("Reading your contacts…")).font(HandyFont.caption) } }
            HStack {
                Text("\(shown.count) \(L("of")) \(people.count) \(L("contacts"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                Button(selecting ? L("Done") : L("Select")) { selecting.toggle(); picked = [] }.textButton().accessibilityIdentifier("book-select")
            }
            if selecting {
                HStack {
                    Button(picked.count == shown.count && !shown.isEmpty ? L("Select none") : "\(L("Select all")) \(shown.count)") {
                        picked = picked.count == shown.count ? [] : Set(shown.map(\.id))
                    }.textButton().font(HandyFont.caption)
                    Spacer()
                    Text("\(picked.count) \(L("selected"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            if let note { Label(L(note), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
            LazyVStack(spacing: 6) {
                ForEach(shown) { p in row(p) }
            }
            if !loading && shown.isEmpty && !people.isEmpty {
                EmptyState(icon: "magnifyingglass", line: "No one matches", sub: "Clear a filter or try fewer letters.")
            }
            birthdayCard
            backupCard
        }
        .alert(L(editing?.title ?? ""), isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField(L(editing?.prompt ?? ""), text: $editValue)
                .keyboardType(editing == .countryCode ? .phonePad : .default)
            Button("\(L("Change")) \(picked.count)") { if let f = editing { bulkEdit(f, editValue) } }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(editing == .countryCode
                 ? L("Numbers that already start with + or 00 are left as they are. A leading 0 is dropped, the way international dialling needs.")
                 : L("This changes the contact on your iPhone and the account it syncs to."))
        }
        .safeAreaInset(edge: .bottom) { if selecting && !picked.isEmpty { bulkBar } }
        .task { if people.isEmpty { await reload() } }
        .sheet(item: $open, onDismiss: { tags = ContactTags.load(); Task { await reload() } }) { p in
            NavigationStack { ContactDetailView(person: p, groups: groups) }
        }
        .sheet(isPresented: $showGroupPicker) {
            NavigationStack { GroupPickerView(groups: groups, ids: Array(picked)) { msg in note = msg; selecting = false; picked = []; Task { await reload() } } }
        }
        .sheet(item: Binding(get: { showMail.map { MailFile(url: $0) } }, set: { showMail = $0?.url })) { f in
            MailComposer(subject: "Contacts", body: "Attached: \(chosen.count) contacts from Tenzy.", attachment: f.url)
        }
        .confirmationDialog("\(L("Delete")) \(picked.count) \(L("contacts?"))", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("\(L("Delete")) \(picked.count) \(L("contacts"))", role: .destructive) { deleteChosen() }
            Button(L("Keep them"), role: .cancel) {}
        } message: {
            Text(L("They're removed from your iPhone and every account they sync to (iCloud, Gmail, Outlook). iPhone has no contacts trash, so this can't be undone — export them first if you might need them."))
        }
    }

    // MARK: pieces

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(HandyColor.textSecondary)
            TextField(L("Search name, company, phone or email"), text: $query).autocorrectionDisabled().textInputAutocapitalization(.never)
                .accessibilityIdentifier("book-search")
            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }.accessibilityLabel(L("Clear search")) }
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ContactBook.Filter.allCases) { f in
                    let on = filters.contains(f)
                    let n = people.filter { ContactBook.passes($0, f, tags: tags[$0.id] ?? []) }.count
                    Button { if on { filters.remove(f) } else { filters.insert(f) } } label: {
                        Label("\(L(f.title)) \(n)", systemImage: f.icon).font(HandyFont.caption)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(on ? HandyColor.accent : HandyColor.surface, in: Capsule())
                            .foregroundStyle(on ? HandyColor.onAccent : HandyColor.textPrimary)
                            .overlay(Capsule().stroke(HandyColor.border, lineWidth: on ? 0 : 1))
                    }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var scopeRow: some View {
        HStack(spacing: HandySpacing.s8) {
            Menu {
                Button(L("All groups")) { group = nil }
                ForEach(groups) { g in Button("\(g.name)\(g.account.isEmpty ? "" : " · \(g.account)")") { group = g.id } }
            } label: { Label(groups.first { $0.id == group }?.name ?? L("All groups"), systemImage: "person.3").font(HandyFont.caption) }
                .compactButton()
            Menu {
                Button(L("All accounts")) { account = nil }
                ForEach(accounts, id: \.self) { a in Button(L(a)) { account = a } }
            } label: { Label(account.map { L($0) } ?? L("All accounts"), systemImage: "tray.2").font(HandyFont.caption) }
                .compactButton()
            Spacer()
            if !filters.isEmpty || group != nil || account != nil || !query.isEmpty {
                Button(L("Clear")) { filters = []; group = nil; account = nil; query = "" }.textButton().font(HandyFont.caption)
            }
        }
    }

    private func row(_ p: ContactBook.Person) -> some View {
        let on = picked.contains(p.id)
        let marks = tags[p.id] ?? []
        return Button {
            if selecting { if on { picked.remove(p.id) } else { picked.insert(p.id) } } else { open = p }
        } label: {
            HStack(spacing: HandySpacing.s12) {
                if selecting {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                        .foregroundStyle(on ? HandyColor.accent : HandyColor.textSecondary)
                }
                ContactAvatar(person: p, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(p.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                        ForEach(ContactBook.Tag.allCases.filter { marks.contains($0) }) { t in
                            Image(systemName: t.icon).font(.system(size: 11)).foregroundStyle(t == .emergency ? HandyColor.danger : HandyColor.amber)
                                .accessibilityLabel(L(t.title))
                        }
                    }
                    Text([p.company.isEmpty ? nil : p.company, p.phones.first.map { "\(L($0.label)) \($0.value)" } ?? p.emails.first?.value]
                            .compactMap { $0 }.joined(separator: " · "))
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if !selecting { Image(systemName: "chevron.right").font(.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            .padding(.vertical, 8).padding(.horizontal, HandySpacing.s12)
            .background(on ? HandyColor.accentSoft : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// What you can do with everyone you ticked.
    private var bulkBar: some View {
        VStack(spacing: HandySpacing.s8) {
            HStack(spacing: HandySpacing.s8) {
                Menu {
                    Button { exportURL = ContactBook.csvFile(chosen, tags: tags, name: exportName) } label: { Label(L("Spreadsheet for Excel (.csv)"), systemImage: "tablecells") }
                    Button { exportURL = ContactBook.vcard(Array(picked), name: exportName) } label: { Label(L("Contact cards (.vcf)"), systemImage: "person.crop.rectangle.stack") }
                    if MailComposer.canSend {
                        Button { showMail = ContactBook.csvFile(chosen, tags: tags, name: exportName) } label: { Label(L("Email as a spreadsheet"), systemImage: "envelope") }
                        Button { showMail = ContactBook.vcard(Array(picked), name: exportName) } label: { Label(L("Email as contact cards"), systemImage: "envelope.badge") }
                    }
                } label: { Label(L("Export"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("book-export")
                Button { showGroupPicker = true } label: { Label(L("Group"), systemImage: "person.3").frame(maxWidth: .infinity) }.secondaryButton()
                Menu {
                    ForEach(ContactBook.Tag.allCases) { t in
                        Button { mark(t, on: true) } label: { Label("\(L("Mark as")) \(L(t.title))", systemImage: t.icon) }
                        Button { mark(t, on: false) } label: { Label("\(L("Unmark")) \(L(t.title))", systemImage: "minus.circle") }
                    }
                } label: { Label(L("Mark"), systemImage: "star").frame(maxWidth: .infinity) }.secondaryButton()
                Menu {
                    ForEach(ContactBook.BulkField.allCases) { f in
                        Button { editValue = f == .countryCode ? defaultCode : ""; editing = f } label: { Label(L(f.title), systemImage: f == .countryCode ? "phone.badge.plus" : "pencil") }
                    }
                } label: { Label(L("Edit"), systemImage: "pencil").frame(maxWidth: .infinity) }.secondaryButton().accessibilityIdentifier("book-bulk-edit")
            }
            Button(role: .destructive) { confirmDelete = true } label: { Label("\(L("Delete")) \(picked.count)", systemImage: "trash").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered).tint(HandyColor.danger)
            if let u = exportURL {
                ShareLink(item: u) { Label("\(L("Save or send")) \(u.lastPathComponent)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .primaryButton()
                Text(L("Save to Files, iCloud Drive or Google Drive, AirDrop it, or send it in any app.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .padding(HandySpacing.s12)
        .background(HandyColor.bg)
        .onChange(of: picked) { _, _ in exportURL = nil }
    }

    private var defaultCode: String {
        switch Locale.current.region?.identifier ?? "US" {
        case "US", "CA": return "+1"
        case "GB": return "+44"
        case "IN": return "+91"
        case "AU": return "+61"
        case "DE": return "+49"
        case "FR": return "+33"
        case "ES": return "+34"
        case "IT": return "+39"
        case "BR": return "+55"
        case "MX": return "+52"
        case "JP": return "+81"
        default: return "+"
        }
    }

    private func bulkEdit(_ f: ContactBook.BulkField, _ value: String) {
        let ids = Array(picked)
        Task {
            let r = await Task.detached(priority: .userInitiated) { ContactBook.bulkSet(ids, field: f, value: value) }.value
            note = r.failed > 0 ? "\(L("Changed")) \(r.changed) · \(r.failed) \(L("couldn't be changed (read-only account)"))"
                                : (r.changed == 0 ? L("Nothing needed changing.") : "\(L("Changed")) \(r.changed) \(L("contacts"))")
            selecting = false; picked = []; editing = nil
            HandyHaptics.success()
            await reload()
        }
    }

    /// Everyone in one file, and a regular nudge to do it again.
    private var backupCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Back up all your contacts"), systemImage: "externaldrive.badge.icloud").font(HandyFont.bodyStrong)
            Text(ContactBackupReminder.last.map { "\(L("Last backup")) \($0.formatted(.relative(presentation: .named)))" } ?? L("Save everyone to one contact-card file in Files, iCloud Drive or Google Drive. It opens on any phone or computer."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if let u = backupURL {
                ShareLink(item: u) { Label("\(L("Save")) \(u.lastPathComponent)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .primaryButton().simultaneousGesture(TapGesture().onEnded { ContactBackupReminder.markDone() })
            } else {
                Button {
                    backupURL = ContactBook.vcard(people.map(\.id), name: "Contacts backup \(Date().formatted(.dateTime.year().month().day()))")
                } label: { Label("\(L("Back up")) \(people.count) \(L("contacts"))", systemImage: "arrow.down.doc").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(people.isEmpty).accessibilityIdentifier("book-backup")
            }
            HandyFlow(spacing: HandySpacing.s8) {
                Text(L("Remind me")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach([(0, "Off"), (7, "Weekly"), (30, "Monthly")], id: \.0) { v in
                    HChip(text: L(v.1), selected: backupEvery == v.0) {
                        Task {
                            if v.0 > 0, !(await NotifyPermission.ensure()) { notifOff = true; return }
                            backupEvery = v.0; await ContactBackupReminder.set(every: v.0)
                            backupNote = v.0 == 7 ? L("On — every Sunday at 7 pm.") : v.0 == 30 ? L("On — the 1st of each month at 7 pm.") : nil
                        }
                    }
                }
            }
            if backupEvery > 0 {
                Button { Task { await ContactBackupReminder.testRun(); backupNote = L("Test sent — it arrives in 5 seconds.") } } label: {
                    Label(L("Test run"), systemImage: "checkmark.seal").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            if let backupNote { Text(backupNote).font(HandyFont.caption).foregroundStyle(HandyColor.success) }
        }
        .cardStyle()
    }

    private var exportName: String {
        if let g = groups.first(where: { $0.id == group }) { return "\(g.name) contacts" }
        if filters.count == 1, let f = filters.first { return "\(f.title) contacts" }
        return "\(picked.count) contacts"
    }

    /// Birthday reminders: one switch, a time, and a Test run.
    private var birthdayCard: some View {
        let soon = ContactBook.upcoming(people, limit: 3)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: $birthdaysOn) { Label(L("Remind me the day before birthdays"), systemImage: "gift").font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent)
            Text(L("Uses the birthdays saved in your contacts. You get a nudge the day before, with their number so you can call or text."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if birthdaysOn {
                Stepper("\(L("At")) \(TimeOfDay(hour: birthdayHour, minute: 0).label)", value: $birthdayHour, in: 6...21).font(HandyFont.caption)
                if soon.isEmpty {
                    Text(L("None of your contacts has a birthday saved yet. Add one in a contact and it's picked up here.")).font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                } else {
                    ForEach(Array(soon.enumerated()), id: \.offset) { _, s in
                        Text("\(s.person.name) — \(s.date.formatted(.dateTime.month(.abbreviated).day()))").font(HandyFont.caption)
                    }
                }
                NotificationsOffCard(isOff: $notifOff)
                Button {
                    Task {
                        guard await NotifyPermission.ensure() else { await MainActor.run { notifOff = true }; return }
                        let p = soon.first?.person ?? ContactBook.Person(id: "sample", given: "Alex", phones: [.init(label: "Mobile", value: "+1 555 0100")])
                        BirthdayReminders.post(p, birthday: soon.first?.date ?? Date().addingTimeInterval(86400), at: nil, id: "")
                        await MainActor.run { note = "Test sent — check your notifications. That's exactly what you'll get the day before." }
                    }
                } label: { Label(L("Test run"), systemImage: "checkmark.seal") }.compactButton().accessibilityIdentifier("bday-test")
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onChange(of: birthdaysOn) { _, on in
            Task {
                if on { let ok = await NotifyPermission.ensure(); await MainActor.run { notifOff = !ok } }
                BirthdayReminders.refresh(people)
            }
        }
        .onChange(of: birthdayHour) { _, _ in BirthdayReminders.refresh(people) }
    }

    // MARK: actions

    private func reload() async {
        loading = true
        let r = await Task.detached(priority: .userInitiated) { ContactBook.load() }.value
        people = r.people; groups = r.groups; accounts = r.accounts; loading = false
        picked = picked.filter { id in r.people.contains { $0.id == id } }
        BirthdayReminders.refresh(r.people)
    }

    private func mark(_ t: ContactBook.Tag, on: Bool) {
        for id in picked { if on { tags[id, default: []].insert(t) } else { tags[id]?.remove(t) } }
        ContactTags.save(tags)
        note = on ? "Marked \(picked.count) as \(t.title)." : "Unmarked \(picked.count)."
    }

    private func deleteChosen() {
        let ids = Array(picked)
        do {
            try ContactBook.delete(ids)
            for id in ids { tags[id] = nil }
            ContactTags.save(tags)
            note = "Deleted \(ids.count) contact\(ids.count == 1 ? "" : "s")."
            selecting = false; picked = []
            Task { await reload() }
        } catch { note = "Couldn't delete — some accounts (like a work directory) don't allow it." }
    }
}

private struct MailFile: Identifiable { let url: URL; var id: String { url.absoluteString } }

/// A contact's photo, or their initials on a soft colour.
struct ContactAvatar: View {
    let person: ContactBook.Person
    var size: CGFloat = 40
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            if let img { Image(uiImage: img).resizable().scaledToFill() }
            else {
                Circle().fill(HandyColor.accentSoft)
                Text(person.initials).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(HandyColor.accent)
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
        .task(id: person.id) {
            guard person.hasPhoto else { img = nil; return }
            let id = person.id
            img = await Task.detached(priority: .utility) {
                (try? CNContactStore().unifiedContact(withIdentifier: id, keysToFetch: [CNContactThumbnailImageDataKey as CNKeyDescriptor]))?
                    .thumbnailImageData.flatMap(UIImage.init(data:))
            }.value
        }
        .accessibilityHidden(true)
    }
}

/// Add the chosen people to a group, or make a new group for them.
private struct GroupPickerView: View {
    let groups: [ContactBook.Group]
    let ids: [String]
    let done: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                TextField(L("New group name (e.g. Soccer parents)"), text: $newName)
                Button(L("Make the group and add them")) {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    guard !n.isEmpty else { return }
                    do { let g = try ContactBook.makeGroup(n); finish(g, name: n) } catch { problem = "This account doesn't allow new groups. Try an iCloud contact." }
                }.disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: { Text(L("New group")) }
            if !groups.isEmpty {
                Section {
                    ForEach(groups) { g in
                        Button { finish(g.id, name: g.name) } label: {
                            HStack { Text(g.name); Spacer(); Text(L(g.account)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                        }
                    }
                } header: { Text(L("Add to a group")) } footer: { Text(L("A group belongs to one account (iCloud, Gmail…). People saved in another account can't join it — that's iPhone's rule.")) }
            }
            if let problem { Text(L(problem)).foregroundStyle(HandyColor.danger) }
        }
        .navigationTitle("\(ids.count) \(L("selected"))").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
    }

    private func finish(_ gid: String, name: String) {
        let failed = ContactBook.add(ids, toGroup: gid)
        let added = ids.count - failed
        done(failed == 0 ? "Added \(added) to \(name)." : "Added \(added) to \(name). \(failed) are in another account, so they couldn't join.")
        dismiss()
    }
}

/// One person: photo, marks, one-tap ways to reach them, birthday, groups, and "plan a call or visit".
struct ContactDetailView: View {
    @State var person: ContactBook.Person
    let groups: [ContactBook.Group]
    @State private var tags: Set<ContactBook.Tag> = []
    @State private var photoPick: PhotosPickerItem?
    @State private var planning = false
    @State private var editing = false
    @State private var note: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: HandySpacing.s16) {
                VStack(spacing: HandySpacing.s8) {
                    ContactAvatar(person: person, size: 96).id(person.hasPhoto)
                    Text(person.name).font(HandyFont.title).multilineTextAlignment(.center)
                    if !person.company.isEmpty || !person.title.isEmpty {
                        Text([person.title, person.company].filter { !$0.isEmpty }.joined(separator: " · ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }
                    HStack(spacing: HandySpacing.s8) {
                        PhotosPicker(selection: $photoPick, matching: .images) { Label(person.hasPhoto ? L("Change photo") : L("Add photo"), systemImage: "camera") }.compactButton()
                        if person.hasPhoto { Button(L("Remove photo")) { setPhoto(nil) }.textButton().font(HandyFont.caption) }
                    }
                }
                HStack(spacing: HandySpacing.s8) {
                    ForEach(ContactBook.Tag.allCases) { t in
                        let on = tags.contains(t)
                        Button { if on { tags.remove(t) } else { tags.insert(t) }; saveTags() } label: {
                            Label(L(t.title), systemImage: t.icon).font(HandyFont.caption).frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(on ? (t == .emergency ? HandyColor.danger : HandyColor.accent) : HandyColor.surface, in: Capsule())
                                .foregroundStyle(on ? Color.white : HandyColor.textPrimary)
                        }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : []).accessibilityIdentifier("tag-\(t.rawValue)")
                    }
                }
                Button { planning = true } label: { Label(L("Plan a call or visit"), systemImage: "calendar.badge.clock").frame(maxWidth: .infinity) }
                    .primaryButton().accessibilityIdentifier("plan-contact")
                if let note { Label(L(note), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                section("Phone", person.phones) { v in
                    HStack {
                        if let u = ContactPlans.telURL(v) { Link(destination: u) { Image(systemName: "phone.fill") }.compactButton().accessibilityLabel(L("Call")) }
                        if let u = URL(string: "sms:\(v.filter { $0.isNumber || $0 == "+" })") { Link(destination: u) { Image(systemName: "message.fill") }.compactButton().accessibilityLabel(L("Message")) }
                    }
                }
                section("Email", person.emails) { v in
                    if let u = URL(string: "mailto:\(v)") { Link(destination: u) { Image(systemName: "envelope.fill") }.compactButton().accessibilityLabel(L("Email")) }
                }
                section("Address", person.addresses) { v in
                    if let u = ContactPlans.mapsURL(v) { Link(destination: u) { Image(systemName: "car.fill") }.compactButton().accessibilityLabel(L("Directions")) }
                }
                section("Social media", person.socials) { v in
                    Button { Copier.copy(v) } label: { Image(systemName: "doc.on.doc") }.compactButton().accessibilityLabel(L("Copy"))
                }
                if let b = person.birthday, let next = ContactBook.nextBirthday(b, after: Date()) {
                    infoRow("gift", L("Birthday"), next.formatted(.dateTime.month(.wide).day()) + (ContactBook.age(b, on: next).map { " · \(L("turns")) \($0)" } ?? ""))
                    let wish = ContactBook.birthdayWish(person, on: next)
                    Text("“\(wish)”").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        if let u = ContactBook.wishURL(person, wish: wish) {
                            Link(destination: u) { Label(L("Send the wish"), systemImage: "message.fill").frame(maxWidth: .infinity) }.compactButton()
                        }
                        Button { Copier.copy(wish) } label: { Label(L("Copy"), systemImage: "doc.on.doc") }.compactButton()
                    }
                }
                let mine = groups.filter { person.groups.contains($0.id) }
                if !mine.isEmpty { infoRow("person.3", L("Groups"), mine.map(\.name).joined(separator: ", ")) }
                if !person.account.isEmpty { infoRow("tray.2", L("Saved in"), L(person.account)) }
                Button { editing = true } label: { Label(L("Edit everything in Contacts"), systemImage: "pencil").frame(maxWidth: .infinity) }.secondaryButton()
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(L("Contact")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        .onAppear { tags = ContactTags.load()[person.id] ?? [] }
        .onChange(of: photoPick) { _, item in
            guard let item else { return }
            Task {
                let img = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init(data:))
                await MainActor.run { photoPick = nil; if let img { setPhoto(img) } }
            }
        }
        .sheet(isPresented: $planning) { NavigationStack { PlanContactView(person: person) { msg in note = msg } } }
        .sheet(isPresented: $editing, onDismiss: { refresh() }) { SystemContactEditor(id: person.id).ignoresSafeArea() }
    }

    private func section<A: View>(_ title: String, _ items: [ContactBook.Labeled], @ViewBuilder actions: @escaping (String) -> A) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L(title)).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary)
                    ForEach(items, id: \.self) { it in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L(it.label)).font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                                Text(it.value).font(HandyFont.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            actions(it.value)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: HandySpacing.s12)
            }
        }
    }

    private func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            Label(title, systemImage: icon).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Spacer()
            Text(value).font(HandyFont.body).multilineTextAlignment(.trailing)
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func saveTags() {
        var all = ContactTags.load(); all[person.id] = tags; ContactTags.save(all)
    }

    private func setPhoto(_ img: UIImage?) {
        do { try ContactBook.setPhoto(person.id, image: img); person.hasPhoto = img != nil; note = img == nil ? "Photo removed." : "Photo saved to the contact." }
        catch { note = "This contact's account doesn't allow photo changes." }
    }

    private func refresh() {
        let r = ContactBook.fetch([person.id]).first
        if let r { person = ContactBook.person(r, account: person.account, groups: person.groups) }
    }
}

/// "Call my doctor at 8 tomorrow" — pick when and how early to be reminded; for a visit, Tenzy works out the
/// drive and adds a "leave now" alert. Adds to your calendar too, then a Test run shows the exact alerts.
private struct PlanContactView: View {
    let person: ContactBook.Person
    let done: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ContactBook.PlanKind = .call
    @State private var start = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var remindBefore = 0
    @State private var note = ""
    @State private var travel: Int?
    @State private var finding = false
    @State private var setup: ContactPlans.Setup?
    @State private var addToCalendar = true
    @State private var showCalendar = false
    @State private var notifOff = false
    @StateObject private var places = NearbyPlaces()

    private var address: String? { person.addresses.first?.value }

    var body: some View {
        Form {
            Section {
                Picker(L("What"), selection: $kind) { ForEach(ContactBook.PlanKind.allCases) { Text(L($0.title)).tag($0) } }.pickerStyle(.segmented)
                DatePicker(L("When"), selection: $start, in: Date()...)
                Picker(L("Remind me"), selection: $remindBefore) {
                    Text(L("At the time")).tag(0); Text(L("10 min before")).tag(10); Text(L("30 min before")).tag(30); Text(L("1 hour before")).tag(60); Text(L("1 day before")).tag(1440)
                }
                TextField(L("Note (e.g. ask about test results)"), text: $note)
            } footer: { Text(L("The alert shows their number and address, with Call and Directions buttons right on it.")) }

            if kind != .call {
                Section {
                    if let address {
                        Text(address).font(HandyFont.caption)
                        if finding { HStack { ProgressView(); Text(L("Working out the drive…")).font(HandyFont.caption) } }
                        else if let t = travel {
                            Label("\(L("About")) \(t) \(L("min drive from here — you'll get a \"leave now\" alert"))", systemImage: "car.fill").font(HandyFont.caption)
                            if let leave = ContactBook.leaveBy(start: start, travelMinutes: t) {
                                Text("\(L("Leave by")) \(leave.formatted(date: .omitted, time: .shortened))").font(HandyFont.bodyStrong)
                            }
                        } else {
                            Button(L("Work out the drive time")) { findTravel() }
                            if places.denied { Text(L("Location is off, so Tenzy can't time the drive. You'll still get the reminder.")).font(HandyFont.micro).foregroundStyle(HandyColor.amber) }
                        }
                    } else {
                        Text(L("No address saved for this contact. Add one with Edit everything in Contacts to get a \"leave now\" alert and directions.")).font(HandyFont.caption).foregroundStyle(HandyColor.amber)
                    }
                } header: { Text(L("Getting there")) }
            }

            Section {
                Toggle(L("Also add it to my calendar"), isOn: $addToCalendar)
            } footer: { Text(L("You'll see the calendar entry before it's added — tap Add to keep it.")) }

            Section {
                Button { setUp() } label: { Label(L("Set it up"), systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity) }
                    .accessibilityIdentifier("plan-setup")
                if let s = setup {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("\(L("Reminder:")) \(s.reminderAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell.fill").font(HandyFont.caption)
                        if let l = s.leaveAt { Label("\(L("Leave now alert:")) \(l.formatted(date: .omitted, time: .shortened))", systemImage: "car.fill").font(HandyFont.caption) }
                    }
                    Button { ContactPlans.testRun(person, kind: kind, start: start, note: note, travelMinutes: travel) } label: {
                        Label(L("Test run — send me these alerts now"), systemImage: "checkmark.seal")
                    }.accessibilityIdentifier("plan-test")
                }
                NotificationsOffCard(isOff: $notifOff)
            }
        }
        .navigationTitle("\(L("Plan with")) \(person.given.isEmpty ? person.name : person.given)").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        .onChange(of: kind) { _, k in if k != .call, travel == nil, address != nil { findTravel() } }
        .sheet(isPresented: $showCalendar) {
            EventEditSheet(event: ICSParse.Event(title: "\(kind == .call ? "Call" : kind == .visit ? "Visit" : "Meet") \(person.name)", start: start,
                                                 end: start.addingTimeInterval(kind == .call ? 900 : 3600), location: address ?? "",
                                                 notes: ([note] + person.phones.prefix(1).map { "Phone: \($0.value)" }).filter { !$0.isEmpty }.joined(separator: "\n")))
                .ignoresSafeArea()
        }
    }

    private func findTravel() {
        guard let address else { return }
        finding = true
        places.locate { here in
            Task {
                let t = await ContactPlans.driveMinutes(to: address, from: here)
                await MainActor.run { travel = t; finding = false }
            }
        }
    }

    private func setUp() {
        Task {
            let ok = await NotifyPermission.ensure()
            await MainActor.run {
                notifOff = !ok
                guard ok else { return }
                setup = ContactPlans.schedule(person, kind: kind, start: start, remindBefore: remindBefore, note: note, travelMinutes: kind == .call ? nil : travel)
                done("Set: \(kind.title.lowercased()) \(person.name) \(start.formatted(date: .abbreviated, time: .shortened)).")
                if addToCalendar { showCalendar = true }
            }
        }
    }
}

/// Apple's own contact editor, for everything else (names, numbers, labels, birthday, social profiles).
private struct SystemContactEditor: UIViewControllerRepresentable {
    let id: String
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UINavigationController {
        let store = CNContactStore()
        let c = (try? store.unifiedContact(withIdentifier: id, keysToFetch: [CNContactViewController.descriptorForRequiredKeys()])) ?? CNContact()
        let vc = CNContactViewController(for: c)
        vc.contactStore = store
        vc.allowsEditing = true
        vc.delegate = context.coordinator
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ vc: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, CNContactViewControllerDelegate {}
}

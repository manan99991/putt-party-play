import SwiftUI
import Contacts
import ContactsUI
import PhotosUI

/// Contacts — nothing open by default: every way to find people is on one screen, in pairs ("No phone number" next
/// to "Has a phone number", "No email" next to "Has an email", first name, last name, company, photo, birthday,
/// address, mobile, only-an-email ↔ only-a-phone), plus your marks, work / home / social, groups and accounts. Each
/// shows how many people it finds. Tap one and only those people open — all ticked — ready to send to someone,
/// save as a spreadsheet, back up, email, mark, group, fix in one go or delete (always confirmed). Narrow it down
/// with more conditions or flip to the opposite in one tap. Search finds anyone by name, company, number or email.
struct ContactsBookView: View {
    @State private var people: [ContactBook.Person] = []
    @State private var groups: [ContactBook.Group] = []
    @State private var accounts: [String] = []
    @State private var tags: [String: Set<ContactBook.Tag>] = ContactTags.load()
    @State private var counts: [ContactBook.Filter: Int] = [:]
    @State private var loading = false
    @State private var query = ""
    @State private var finding: ContactFinding?
    @State private var open: ContactBook.Person?
    @AppStorage("birthdays.on") private var birthdaysOn = false
    @AppStorage("birthdays.hour") private var birthdayHour = 9
    @State private var notifOff = false
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            searchBar
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                searchResults
            } else {
                finder
            }
            if let note { Label(L(note), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
            birthdayCard
        }
        .task { if people.isEmpty { await reload() } }
        .sheet(item: $finding, onDismiss: { tags = ContactTags.load(); Task { await reload() } }) { f in
            NavigationStack { ContactResultsView(people: people, groups: groups, finding: f) }
        }
        .sheet(item: $open, onDismiss: { tags = ContactTags.load(); Task { await reload() } }) { p in
            NavigationStack { ContactDetailView(person: p, groups: groups) }
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

    /// While typing: who matches, and one tap to work on all of them.
    private var searchResults: some View {
        let found = ContactBook.filtered(people, query: query, filters: [], group: nil, account: nil, tags: tags)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(found.count) \(L(found.count == 1 ? "contact" : "contacts"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                if found.count > 1 {
                    Button { finding = ContactFinding(query: query) } label: { Label(L("Work on all of them"), systemImage: "checklist") }.textButton().font(HandyFont.caption)
                }
            }
            ForEach(found.prefix(25)) { p in
                Button { open = p } label: { ContactRow(person: p, marks: tags[p.id] ?? [], picked: nil) }.buttonStyle(.plain)
            }
            if found.count > 25 {
                Button { finding = ContactFinding(query: query) } label: { Text("\(L("See all")) \(found.count)").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if found.isEmpty, !loading { EmptyState(icon: "magnifyingglass", line: "No one matches", sub: "Try fewer letters, or part of their number.") }
        }
    }

    /// Every way to find people, on one screen, with how many each finds.
    private var finder: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Find contacts that…")).font(HandyFont.title)
                Spacer()
                if loading { BusySpinner() } else {
                    Text("\(people.count) \(L("in all"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Text(L("Tap one to see just those people — then send, save, back up or fix them together."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            ForEach(ContactBook.Filter.pairs, id: \.0) { pair in
                HStack(spacing: 8) {
                    finderButton(pair.0, missing: true)
                    finderButton(pair.1, missing: false)
                }
            }
            Text(L("Your marks")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary).padding(.top, 4)
            HStack(spacing: 8) { ForEach(ContactBook.Filter.marks) { finderButton($0, missing: false, small: true) } }
            Text(L("Kind of contact")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary).padding(.top, 4)
            HStack(spacing: 8) { ForEach(ContactBook.Filter.kinds) { finderButton($0, missing: false, small: true) } }
            if !groups.isEmpty || accounts.count > 1 {
                Text(L("Groups and accounts")).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textSecondary).padding(.top, 4)
                HStack(spacing: 8) {
                    if !groups.isEmpty {
                        Menu {
                            ForEach(groups) { g in
                                Button("\(g.name) · \(people.filter { $0.groups.contains(g.id) }.count)") { finding = ContactFinding(group: g.id, title: g.name) }
                            }
                        } label: { scopeLabel(L("A group"), "person.3.fill", groups.count) }
                    }
                    if accounts.count > 1 {
                        Menu {
                            ForEach(accounts, id: \.self) { a in
                                Button("\(L(a)) · \(people.filter { $0.account == a }.count)") { finding = ContactFinding(account: a, title: L(a)) }
                            }
                        } label: { scopeLabel(L("An account"), "tray.2.fill", accounts.count) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contacts-finder")
    }

    private func scopeLabel(_ title: String, _ icon: String, _ n: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(HandyColor.accent).frame(width: 22)
            Text(title).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
            Spacer(minLength: 0)
            Text("\(n)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .padding(.horizontal, 12).frame(minHeight: 52)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private func finderButton(_ f: ContactBook.Filter, missing: Bool, small: Bool = false) -> some View {
        let n = counts[f] ?? 0
        return Button { finding = ContactFinding(filters: [f]) } label: {
            HStack(spacing: 8) {
                Image(systemName: f.icon).font(.system(size: small ? 14 : 16, weight: .semibold))
                    .foregroundStyle(n == 0 ? HandyColor.textSecondary : (missing ? HandyColor.amber : HandyColor.accent)).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L(f.title)).font(small ? HandyFont.caption.weight(.semibold) : HandyFont.caption.weight(.semibold))
                        .foregroundStyle(HandyColor.textPrimary).lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                    Text(loading && people.isEmpty ? "…" : "\(n)").font(HandyFont.micro.monospacedDigit()).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
            .opacity(n == 0 && !loading ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(n == 0 && !loading)
        .accessibilityLabel(Text("\(L(f.title)), \(n)"))
        .accessibilityIdentifier("find-\(f.rawValue)")
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
        let t = ContactTags.load()
        let c = await Task.detached(priority: .userInitiated) { ContactBook.counts(r.people, tags: t) }.value
        people = r.people; groups = r.groups; accounts = r.accounts; tags = t; counts = c; loading = false
        BirthdayReminders.refresh(r.people)
    }
}

/// What a tap on the finder asks for: conditions, a search, a group or an account.
struct ContactFinding: Identifiable {
    let id = UUID()
    var filters: Set<ContactBook.Filter> = []
    var query = ""
    var group: String? = nil
    var account: String? = nil
    var title: String? = nil
}

/// One person in a list: photo or initials, name with their marks, and the first useful detail.
struct ContactRow: View {
    let person: ContactBook.Person
    let marks: Set<ContactBook.Tag>
    /// nil = not choosing; true/false = ticked or not.
    let picked: Bool?
    var body: some View {
        HStack(spacing: HandySpacing.s12) {
            if let on = picked {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                    .foregroundStyle(on ? HandyColor.accent : HandyColor.textSecondary)
            }
            ContactAvatar(person: person, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(person.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).lineLimit(1)
                    ForEach(ContactBook.Tag.allCases.filter { marks.contains($0) }) { t in
                        Image(systemName: t.icon).font(.system(size: 11)).foregroundStyle(t == .emergency ? HandyColor.danger : HandyColor.amber)
                            .accessibilityLabel(L(t.title))
                    }
                }
                Text([person.company.isEmpty ? nil : person.company, person.phones.first.map { "\(L($0.label)) \($0.value)" } ?? person.emails.first?.value]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if picked == nil { Image(systemName: "chevron.right").font(.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .padding(.vertical, 8).padding(.horizontal, HandySpacing.s12)
        .background(picked == true ? HandyColor.accentSoft : HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(picked == true ? [.isButton, .isSelected] : .isButton)
    }
}

/// The people a finder tap found — all ticked — and everything you can do with them together.
struct ContactResultsView: View {
    let groups: [ContactBook.Group]
    @State private var people: [ContactBook.Person]
    @State private var tags: [String: Set<ContactBook.Tag>] = ContactTags.load()
    @State private var filters: Set<ContactBook.Filter>
    @State private var query: String
    @State private var group: String?
    @State private var account: String?
    private let title: String?
    @State private var picked: Set<String> = []
    @State private var touched = false
    @State private var open: ContactBook.Person?
    @State private var ready: (url: URL, lead: KeepShare.Lead)?
    @State private var showMail: URL?
    @State private var showGroupPicker = false
    @State private var confirmDelete = false
    @State private var editing: ContactBook.BulkField?
    @State private var editValue = ""
    @State private var note: String?
    @Environment(\.dismiss) private var dismiss

    init(people: [ContactBook.Person], groups: [ContactBook.Group], finding f: ContactFinding) {
        self.groups = groups
        _people = State(initialValue: people)
        _filters = State(initialValue: f.filters)
        _query = State(initialValue: f.query)
        _group = State(initialValue: f.group)
        _account = State(initialValue: f.account)
        title = f.title
    }

    private var shown: [ContactBook.Person] {
        ContactBook.filtered(people, query: query, filters: filters, group: group, account: account, tags: tags)
    }
    private var chosen: [ContactBook.Person] { shown.filter { picked.contains($0.id) } }
    private var heading: String {
        if let title { return title }
        if !query.isEmpty { return "“\(query)”" }
        return filters.sorted { $0.rawValue < $1.rawValue }.map { L($0.title) }.joined(separator: " + ")
    }
    private let actionCols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                conditions
                actions
                if let note { Label(L(note), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                HStack {
                    Text("\(chosen.count) \(L("of")) \(shown.count) \(L("ticked"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Spacer()
                    Button(chosen.count == shown.count ? L("Tick none") : L("Tick all")) {
                        touched = true
                        picked = chosen.count == shown.count ? [] : Set(shown.map(\.id))
                    }.textButton().font(HandyFont.caption).accessibilityIdentifier("results-tick-all")
                }
                LazyVStack(spacing: 6) {
                    ForEach(shown) { p in
                        HStack(spacing: 6) {
                            Button {
                                touched = true
                                if picked.contains(p.id) { picked.remove(p.id) } else { picked.insert(p.id) }
                            } label: { ContactRow(person: p, marks: tags[p.id] ?? [], picked: picked.contains(p.id)) }
                                .buttonStyle(.plain)
                            Button { open = p } label: { Image(systemName: "info.circle").font(.system(size: 20)).frame(width: 36, height: 44) }
                                .buttonStyle(.plain).foregroundStyle(HandyColor.accent).accessibilityLabel("\(L("Open")) \(p.name)")
                        }
                    }
                }
                if shown.isEmpty { EmptyState(icon: "checkmark.circle", line: "No one left here", sub: "Everyone that matched has been sorted out.") }
            }
            .padding(HandySpacing.gutter)
        }
        .background(Ground())
        .navigationTitle(heading).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        .onAppear { if !touched { picked = Set(shown.map(\.id)) } }
        .onChange(of: filters) { _, _ in picked = Set(shown.map(\.id)); ready = nil }
        .sheet(item: $open, onDismiss: { Task { await reload() } }) { p in NavigationStack { ContactDetailView(person: p, groups: groups) } }
        .sheet(isPresented: $showGroupPicker) {
            NavigationStack { GroupPickerView(groups: groups, ids: chosen.map(\.id)) { msg in note = msg; Task { await reload() } } }
        }
        .sheet(item: Binding(get: { showMail.map { MailFile(url: $0) } }, set: { showMail = $0?.url })) { f in
            MailComposer(subject: "Contacts", body: "Attached: \(chosen.count) contacts.", attachment: f.url)
        }
        .alert(L(editing?.title ?? ""), isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField(L(editing?.prompt ?? ""), text: $editValue).keyboardType(editing == .countryCode ? .phonePad : .default)
            Button("\(L("Change")) \(chosen.count)") { if let f = editing { bulkEdit(f, editValue) } }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(editing == .countryCode
                 ? L("Numbers that already start with + or 00 are left as they are. A leading 0 is dropped, the way international dialling needs.")
                 : L("This changes the contact on your iPhone and the account it syncs to."))
        }
        .confirmationDialog("\(L("Delete")) \(chosen.count) \(L("contacts?"))", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("\(L("Delete")) \(chosen.count) \(L("contacts"))", role: .destructive) { deleteChosen() }
            Button(L("Keep them"), role: .cancel) {}
        } message: {
            Text(L("They're removed from your iPhone and every account they sync to (iCloud, Gmail, Outlook). iPhone has no contacts trash, so this can't be undone — export them first if you might need them."))
        }
    }

    /// What's being shown, the opposite in one tap, and more conditions to narrow it down.
    private var conditions: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("\(shown.count) \(L(shown.count == 1 ? "contact" : "contacts"))").font(HandyFont.title)
            HandyFlow(spacing: 6) {
                ForEach(filters.sorted { $0.rawValue < $1.rawValue }) { f in
                    Button { filters.remove(f) } label: {
                        Label(L(f.title), systemImage: "xmark").font(HandyFont.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(HandyColor.accentSoft, in: Capsule()).foregroundStyle(HandyColor.textPrimary)
                    }.buttonStyle(.plain).accessibilityLabel("\(L("Remove")) \(L(f.title))")
                }
                Menu {
                    ForEach(ContactBook.Filter.allCases.filter { f in !filters.contains(f) && !(f.opposite.map(filters.contains) ?? false) }) { f in
                        Button("\(L(f.title)) · \(shown.filter { ContactBook.passes($0, f, tags: tags[$0.id] ?? []) }.count)") { filters.insert(f) }
                    }
                } label: {
                    Label(L("Narrow it down"), systemImage: "plus").font(HandyFont.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(Capsule().stroke(HandyColor.accent, lineWidth: 1)).foregroundStyle(HandyColor.accent)
                }.accessibilityIdentifier("results-narrow")
            }
            if filters.count == 1, let f = filters.first, let o = f.opposite {
                Button { filters = [o] } label: {
                    Label("\(L("Show the opposite")): \(L(o.title))", systemImage: "arrow.left.arrow.right").font(HandyFont.caption)
                }.textButton().accessibilityIdentifier("results-opposite")
            }
        }
    }

    /// Everything you can do with the ticked people, all on screen.
    private var actions: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            LazyVGrid(columns: actionCols, spacing: 8) {
                tile("Send", "paperplane.fill", "results-send") { ready = ContactBook.vcard(chosen.map(\.id), name: exportName).map { ($0, .share) } }
                tile("Spreadsheet", "tablecells.fill", "results-csv") { ready = ContactBook.csvFile(chosen, tags: tags, name: exportName).map { ($0, .save) } }
                tile("Back up", "externaldrive.fill.badge.icloud", "results-backup") {
                    ready = ContactBook.vcard(chosen.map(\.id), name: "\(exportName) backup \(Date().formatted(.dateTime.year().month().day()))").map { ($0, .save) }
                }
                if MailComposer.canSend {
                    tile("Email", "envelope.fill", "results-email") { showMail = ContactBook.vcard(chosen.map(\.id), name: exportName) }
                }
                Menu {
                    ForEach(ContactBook.Tag.allCases) { t in
                        Button { mark(t, on: true) } label: { Label("\(L("Mark as")) \(L(t.title))", systemImage: t.icon) }
                        Button { mark(t, on: false) } label: { Label("\(L("Unmark")) \(L(t.title))", systemImage: "minus.circle") }
                    }
                } label: { tileLabel("Mark", "star.fill") }.disabled(chosen.isEmpty)
                tile("Group", "person.3.fill", "results-group") { showGroupPicker = true }
                Menu {
                    ForEach(ContactBook.BulkField.allCases) { f in
                        Button { editValue = f == .countryCode ? defaultCode : ""; editing = f } label: { Label(L(f.title), systemImage: f == .countryCode ? "phone.badge.plus" : "pencil") }
                    }
                } label: { tileLabel("Fix", "pencil") }.disabled(chosen.isEmpty).accessibilityIdentifier("book-bulk-edit")
                tile("Delete", "trash.fill", "results-delete", danger: true) { confirmDelete = true }
            }
            if let r = ready {
                KeepShare([.file(r.url)], lead: r.lead, tool: "Contacts", record: false).id(r.url)
                Text(L("Save to Files, iCloud Drive or Google Drive, AirDrop it, or send it in any app.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func tile(_ title: String, _ icon: String, _ id: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { tileLabel(title, icon, danger: danger) }
            .buttonStyle(.plain).disabled(chosen.isEmpty).accessibilityIdentifier(id)
    }
    private func tileLabel(_ title: String, _ icon: String, danger: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
            Text(L(title)).font(HandyFont.micro).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(chosen.isEmpty ? HandyColor.textSecondary : (danger ? HandyColor.danger : HandyColor.accent))
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private var exportName: String {
        if let title { return "\(title) contacts" }
        if filters.count == 1, let f = filters.first { return "\(f.title) contacts" }
        return "\(chosen.count) contacts"
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

    private func reload() async {
        let r = await Task.detached(priority: .userInitiated) { ContactBook.load() }.value
        people = r.people; tags = ContactTags.load()
        picked = picked.filter { id in r.people.contains { $0.id == id } }
    }

    private func mark(_ t: ContactBook.Tag, on: Bool) {
        for p in chosen { if on { tags[p.id, default: []].insert(t) } else { tags[p.id]?.remove(t) } }
        ContactTags.save(tags)
        note = on ? "Marked \(chosen.count) as \(t.title)." : "Unmarked \(chosen.count)."
    }

    private func bulkEdit(_ f: ContactBook.BulkField, _ value: String) {
        let ids = chosen.map(\.id)
        Task {
            let r = await Task.detached(priority: .userInitiated) { ContactBook.bulkSet(ids, field: f, value: value) }.value
            note = r.failed > 0 ? "\(L("Changed")) \(r.changed) · \(r.failed) \(L("couldn't be changed (read-only account)"))"
                                : (r.changed == 0 ? L("Nothing needed changing.") : "\(L("Changed")) \(r.changed) \(L("contacts"))")
            editing = nil
            HandyHaptics.success()
            await reload()
        }
    }

    private func deleteChosen() {
        let ids = chosen.map(\.id)
        do {
            try ContactBook.delete(ids)
            for id in ids { tags[id] = nil }
            ContactTags.save(tags)
            note = "Deleted \(ids.count) contact\(ids.count == 1 ? "" : "s")."
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
        .frame(width: size, height: size).clipShape(Circle()).contentShape(Rectangle())
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
        .sheet(isPresented: $editing, onDismiss: { refresh() }) {
            AppleContactCard(close: { editing = false }) { SystemContactEditor(id: person.id) { editing = false } }
        }
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
                        if finding { HStack { BusySpinner(); Text(L("Working out the drive…")).font(HandyFont.caption) } }
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
    let onDone: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }
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
    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) { onDone() }
    }
}

/// Apple's own contact card, shown from Tenzy, with a way out that never depends on Apple's bar. On iOS 26 the card
/// draws its own header (just "Edit"), hides any button an app adds to it, and swallows the swipe-down — so a person
/// opened it and couldn't get back (Manan, 22 Nov). Tenzy's Close sits in its own strip above the card, always there,
/// in view and in edit mode alike; Apple's ✓ still saves an edit, Close leaves without changing anything.
struct AppleContactCard<Card: View>: View {
    let close: () -> Void
    @ViewBuilder let card: () -> Card
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) {
                    Label(L("Close"), systemImage: "xmark").font(HandyFont.bodyStrong)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(HandyColor.surface, in: Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(HandyColor.textPrimary)
                .accessibilityIdentifier("contact-card-close")
                Spacer()
            }
            .padding(.horizontal, HandySpacing.gutter).padding(.vertical, 8)
            .background(HandyColor.bg)
            card().ignoresSafeArea(edges: .bottom)
        }
        .presentationDragIndicator(.visible)
    }
}

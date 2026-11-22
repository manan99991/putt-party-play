import SwiftUI
import Contacts
import ContactsUI
import MessageUI

/// Contacts cleanup — back up to a .vcf, find duplicates, and merge them without losing a number.
/// Everything runs on-device. A merge is permanent (iOS has no contacts trash), so backup comes first.
struct ContactsView: View {
    @State private var authorized = ContactsEngine.authorized()
    @State private var report: ContactsReport?
    @State private var scanning = false
    @State private var busy = false
    @State private var error: String?
    @State private var backupURL: URL?
    @State private var pendingMerge: [ContactRec]?
    @State private var pendingMergeAll: [[ContactRec]]?
    @State private var mergeProgress: String?
    @State private var tidy: TidyGroup?
    @StateObject private var autoBackup = ContactsBackup()
    @State private var backupNote: String?
    @State private var showMail = false
    @State private var showTransfer = false
    @State private var notifOff = false

    struct TidyGroup: Identifiable { let id = UUID(); let title: String; let icon: String; let recs: [ContactRec]; let deletable: Bool }

    var body: some View {
        ToolPage(title: "Contacts", subtitle: "Find anyone by what they have or what's missing, then send, save, back up or fix them together. Duplicates merged, backups on a schedule. All on your phone.", working: busy) {
            HowTo("contacts", [
                "Find contacts that…: tap any box — No email, Has a company, No birthday… — to see just those people.",
                "They open all ticked: send them to someone, save a spreadsheet, back up, mark, group, fix or delete them together.",
                "Clean up merges duplicates without losing a number. Back up keeps a copy on the schedule you pick.",
            ])

            if !authorized {
                permissionCard
            } else {
                ContactsBookView()
                Text(L("Clean up")).font(HandyFont.title).padding(.top, HandySpacing.s8)
                if scanning { HStack { BusySpinner(); Text(L("Reading your contacts…")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                if let r = report { reportBody(r) }
                Button { showTransfer = true } label: {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right.circle.fill").font(.system(size: 26)).foregroundStyle(HandyColor.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Move contacts between accounts")).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                            Text(L("Gmail, iCloud, your phone: copy or move in three taps.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                    }.cardStyle(padding: HandySpacing.s12)
                }.buttonStyle(.plain).accessibilityIdentifier("move-contacts")
                if let error { Text(error).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
                Text(L("Back up")).font(HandyFont.title).padding(.top, HandySpacing.s8)
                autoBackupCard
            }
            Text(L("Everything runs on your phone; nothing is uploaded. A merge is permanent — iOS has no contacts trash — so back up before you merge."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .task {
            // One backup schedule: an older "remind me" choice becomes the automatic backup (which reminds too).
            if ContactBackupReminder.every > 0, autoBackup.frequency == .off {
                autoBackup.frequency = ContactBackupReminder.every >= 30 ? .monthly : .weekly
                await ContactBackupReminder.set(every: 0)
            }
            if authorized && report == nil { scan() }
            await autoBackupIfDue()
        }
        .sheet(isPresented: $showMail) {
            if let url = autoBackup.lastBackupURL {
                MailComposer(subject: "My contacts backup", body: "Attached is a backup of my contacts (.vcf). Keep it somewhere safe.", attachment: url)
            }
        }
        .confirmationDialog(L("Merge these contacts?"),
                            isPresented: Binding(get: { pendingMerge != nil }, set: { if !$0 { pendingMerge = nil } }),
                            titleVisibility: .visible) {
            Button("Merge \(pendingMerge?.count ?? 0) into one", role: .destructive) { if let g = pendingMerge { doMerge(g) }; pendingMerge = nil }
            Button(L("Cancel"), role: .cancel) { pendingMerge = nil }
        } message: {
            Text(L("Every number and email is kept on one contact; the duplicates are removed. This can't be undone, so make sure you've backed up."))
        }
        .confirmationDialog(L("Merge all duplicate groups?"),
                            isPresented: Binding(get: { pendingMergeAll != nil }, set: { if !$0 { pendingMergeAll = nil } }),
                            titleVisibility: .visible) {
            Button("Merge all \(pendingMergeAll?.count ?? 0) groups", role: .destructive) { if let gs = pendingMergeAll { doMergeAll(gs) }; pendingMergeAll = nil }
            Button(L("Cancel"), role: .cancel) { pendingMergeAll = nil }
        } message: {
            Text(L("Each group collapses to one contact, keeping every number and email. This can't be undone, so make sure you've backed up."))
        }
        .sheet(isPresented: $showTransfer) { NavigationStack { ContactsTransferView(onChanged: { scan() }) } }
        .sheet(item: $tidy) { g in
            NavigationStack {
                ContactsTidySheet(group: g, onChanged: { scan() })
                    .navigationTitle(g.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { tidy = nil } } }
            }
        }
    }

    private var permissionCard: some View {
        VStack(spacing: HandySpacing.s16) {
            EmptyState(icon: "person.2.fill", line: "Contacts needs access",
                       sub: "To find duplicates and back up, it needs to read your contacts. Nothing is uploaded — it all stays on your phone.")
            Button {
                if Permission.contactsDenied { Permission.openSettings() }
                else { Task { authorized = await ContactsEngine.requestAccess(); if authorized { scan() } } }
            } label: {
                Label(Permission.contactsDenied ? "Open Settings to allow contacts" : "Allow contacts access",
                      systemImage: Permission.contactsDenied ? "gearshape" : "lock.open").frame(maxWidth: .infinity)
            }.primaryButton()
        }
    }

    @ViewBuilder private func reportBody(_ r: ContactsReport) -> some View {
        HStack {
            Text("\(r.total) contacts · \(r.duplicateCount) duplicate\(r.duplicateCount == 1 ? "" : "s")")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Spacer()
            Button { scan() } label: { Label(L("Rescan"), systemImage: "arrow.clockwise") }.textButton().disabled(scanning || busy)
        }

        if r.duplicateGroups.isEmpty {
            Text(L("No duplicates found.")).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
        }

        // Merge every duplicate group in one go — each group collapses to a single contact.
        if r.duplicateGroups.count > 1 {
            Button { pendingMergeAll = r.duplicateGroups } label: {
                HStack {
                    if busy { BusySpinner().tint(.white) }
                    Label(mergeProgress ?? "Merge all \(r.duplicateGroups.count) duplicate groups", systemImage: "arrow.triangle.merge")
                }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(busy)
        }

        ForEach(Array(r.duplicateGroups.enumerated()), id: \.offset) { _, g in
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                ForEach(g) { rec in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.hasName ? rec.name : "(no name)").font(HandyFont.bodyStrong)
                        if !rec.subtitle.isEmpty { Text(rec.subtitle).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { pendingMerge = g } label: {
                    Label("Merge \(g.count) into one", systemImage: "arrow.triangle.merge").frame(maxWidth: .infinity)
                }.secondaryButton().disabled(busy)
            }.cardStyle()
        }

        // Tidy up — health buckets, each opening a list with one-tap fixes.
        let buckets: [TidyGroup] = [
            TidyGroup(title: "No name at all", icon: "person.fill.questionmark", recs: r.noName, deletable: false),
            TidyGroup(title: "Empty — nothing saved", icon: "person.crop.circle.badge.xmark", recs: r.empty, deletable: true),
        ].filter { !$0.recs.isEmpty }
        if !buckets.isEmpty {
            Text(L("Tidy up")).font(HandyFont.bodyStrong)
            ForEach(buckets) { b in
                Button { tidy = b } label: {
                    HStack(spacing: HandySpacing.s12) {
                        Image(systemName: b.icon).foregroundStyle(HandyColor.accent).frame(width: 24)
                        Text(b.title).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                        Spacer()
                        Text("\(b.recs.count)").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textSecondary)
                        Image(systemName: "chevron.right").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    }.padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        } else {
            Text(L("No empty or nameless contacts. ✓")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }

    }

    // MARK: actions

    private func scan() {
        scanning = true; error = nil
        Task {
            let r = await Task.detached { ContactsEngine.scan() }.value
            await MainActor.run { report = r; scanning = false }
        }
    }

    // MARK: automatic backup

    private var autoBackupCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L("Back up automatically"), systemImage: "clock.arrow.circlepath").font(HandyFont.bodyStrong)
                Spacer()
                Text(autoBackup.lastBackup.map { "Last: " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "Never")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            Text(L("Saves a dated copy to the Files app (and iCloud Drive if it's on) on the schedule you pick, so a lost phone never means lost contacts."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(BackupFrequency.allCases, id: \.rawValue) { f in
                    HChip(text: L(f.title), selected: autoBackup.frequency == f) {
                        Task {
                            if f != .off, !(await NotifyPermission.ensure()) { notifOff = true }
                            autoBackup.frequency = f
                            if f != .off { runBackupNow() }
                        }
                    }
                }
            }
            NotificationsOffCard(isOff: $notifOff)
            if autoBackup.frequency != .off {
                Button { Task { await ContactBackupReminder.testRun(); backupNote = L("Test sent — it arrives in 5 seconds."); backupNote = await NotifyCheck.report() } } label: {
                    Label(L("Test run"), systemImage: "checkmark.seal")
                }.compactButton().accessibilityIdentifier("backup-test")
            }
            if let backupNote { Text(backupNote).font(HandyFont.micro).foregroundStyle(HandyColor.accent) }
            Button { runBackupNow() } label: {
                HStack { if busy { BusySpinner() }; Label("\(L("Back up all")) \(report?.total ?? 0) \(L("contacts now"))", systemImage: "arrow.down.doc.fill") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(busy).accessibilityIdentifier("backup-now")
            HStack(spacing: HandySpacing.s8) {
                if autoBackup.lastBackupURL != nil {
                    if MailComposer.canSend { Button { showMail = true } label: { Label(L("Email a copy"), systemImage: "envelope") }.compactButton() }
                    if let u = autoBackup.lastBackupURL { ShareLink(item: u) { Label(L("Share the backup"), systemImage: "square.and.arrow.up") }.compactButton() }
                }
            }
        }.cardStyle(padding: HandySpacing.s12)
    }

    private func runBackupNow() {
        busy = true; error = nil
        Task {
            do { let url = try await autoBackup.runBackup(); backupNote = "Backed up \(url.lastPathComponent) to Files"; HandyHaptics.success() }
            catch { self.error = "Couldn't back up your contacts. Try again." }
            busy = false
        }
    }

    private func autoBackupIfDue() async {
        guard authorized, autoBackup.isDue() else { return }
        do { let url = try await autoBackup.runBackup(); backupNote = "Auto-backed up \(url.lastPathComponent) to Files" }
        catch { /* silent — the manual button and reminder still cover the user */ }
    }

    private func doMerge(_ g: [ContactRec]) {
        busy = true; error = nil
        Task {
            do {
                try await Task.detached { try ContactsEngine.merge(g) }.value
                await MainActor.run { busy = false; HandyHaptics.success(); scan() }
            } catch {
                await MainActor.run { self.error = "Couldn't merge those contacts."; busy = false }
            }
        }
    }

    /// Merge every duplicate group in turn. One failing group doesn't stop the rest; the count of any
    /// that couldn't merge is surfaced at the end, and a rescan refreshes what's left.
    private func doMergeAll(_ groups: [[ContactRec]]) {
        busy = true; error = nil
        Task {
            var failed = 0
            for (i, g) in groups.enumerated() {
                await MainActor.run { mergeProgress = "Merging \(i + 1) of \(groups.count)…" }
                do { try await Task.detached { try ContactsEngine.merge(g) }.value }
                catch { failed += 1 }
            }
            await MainActor.run {
                busy = false; mergeProgress = nil
                if failed > 0 { self.error = "\(failed) group\(failed == 1 ? "" : "s") couldn't be merged. The rest were." }
                else { HandyHaptics.success() }
                scan()
            }
        }
    }
}

/// A tidy-up bucket: list the contacts, fix one by tapping it open in the system editor, export the
/// set as a .vcf, or — for the "empty" bucket — delete them in one go after a confirm.
private struct ContactsTidySheet: View {
    let group: ContactsView.TidyGroup
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editing: EditTarget?
    @State private var shareURL: URL?
    @State private var confirmDelete = false
    @State private var busy = false

    private struct EditTarget: Identifiable { let id: String }

    var body: some View {
        List {
            Section {
                ForEach(group.recs) { rec in
                    Button { editing = EditTarget(id: rec.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.hasName ? rec.name : "(no name)").font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                                if !rec.subtitle.isEmpty { Text(rec.subtitle).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                            }
                            Spacer()
                            Image(systemName: "pencil").foregroundStyle(HandyColor.accent)
                        }
                    }
                }
            } footer: {
                Text(group.deletable ? "These have no name and no number — usually safe to delete. Back up first."
                                     : "Tap one to add what's missing in the contact editor.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: HandySpacing.s8) {
                if let url = shareURL {
                    ShareLink(item: url) { Label(L("Share .vcf"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                } else {
                    Button { exportGroup() } label: {
                        HStack { if busy { BusySpinner() }; Label(L("Export (.vcf)"), systemImage: "square.and.arrow.up") }.frame(maxWidth: .infinity)
                    }.secondaryButton().disabled(busy)
                }
                if group.deletable {
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete \(group.recs.count)", systemImage: "trash").frame(maxWidth: .infinity) }.primaryButton().disabled(busy)
                }
            }.padding(HandySpacing.s12).background(.ultraThinMaterial)
        }
        .sheet(item: $editing) { t in
            ContactEditor(id: t.id) { editing = nil; onChanged() }.ignoresSafeArea()
        }
        .confirmationDialog("Delete \(group.recs.count) empty contacts?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete \(group.recs.count)", role: .destructive) { deleteAll() }
            Button(L("Cancel"), role: .cancel) {}
        } message: { Text(L("They have no name and no number. This can't be undone.")) }
    }

    private func exportGroup() {
        busy = true
        let ids = group.recs.map(\.id); let label = group.title
        Task {
            let url = try? await Task.detached { try ContactsEngine.exportVCard(ids: ids, label: label) }.value
            await MainActor.run { busy = false; shareURL = url }
        }
    }
    private func deleteAll() {
        busy = true
        let ids = group.recs.map(\.id)
        Task {
            try? await Task.detached { try ContactsEngine.delete(ids: ids) }.value
            await MainActor.run { busy = false; HandyHaptics.success(); onChanged(); dismiss() }
        }
    }
}

/// Wraps the system contact editor so a missing name/number can be fixed in one tap, in the familiar UI.
private struct ContactEditor: UIViewControllerRepresentable {
    let id: String
    let onDone: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }
    func makeUIViewController(context: Context) -> UINavigationController {
        let store = CNContactStore()
        let keys = [CNContactViewController.descriptorForRequiredKeys()]
        let vc: CNContactViewController
        if let c = try? store.unifiedContact(withIdentifier: id, keysToFetch: keys) { vc = CNContactViewController(for: c) }
        else { vc = CNContactViewController(forNewContact: nil) }
        vc.allowsEditing = true
        vc.allowsActions = true
        vc.delegate = context.coordinator
        // Apple's card has no way back on its own when shown from another app: a Done that always closes it.
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in context.coordinator.onDone() })
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) { onDone() }
    }
}

/// One-tap "email me a copy" of the autoBackup. iOS can't send mail silently, so this opens the system
/// composer with the .vcf already attached; the user hits send. `canSend` is false on a device with no
/// Mail account, so the button is hidden rather than dead.
struct MailComposer: UIViewControllerRepresentable {
    static var canSend: Bool { MFMailComposeViewController.canSendMail() }
    let subject: String
    let body: String
    let attachment: URL
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let data = try? Data(contentsOf: attachment) {
            vc.addAttachmentData(data, mimeType: "text/vcard", fileName: attachment.lastPathComponent)
        }
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { dismiss() }
    }
}

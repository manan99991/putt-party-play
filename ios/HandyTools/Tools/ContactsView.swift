import SwiftUI
import Contacts
import ContactsUI

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

    struct TidyGroup: Identifiable { let id = UUID(); let title: String; let icon: String; let recs: [ContactRec]; let deletable: Bool }

    var body: some View {
        ToolPage(title: "Contacts", subtitle: "Find duplicates, merge them without losing a number, and back everything up — all on your phone.") {
            HowTo("contacts", [
                "Back up to a .vcf first — one tap, keep it somewhere safe.",
                "Review the duplicate groups and merge the ones that match.",
                "Merging keeps every number and email; the extra copies are removed.",
            ])

            if !authorized {
                permissionCard
            } else {
                backupBar
                if scanning { HStack { ProgressView(); Text("Reading your contacts…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
                if let r = report { reportBody(r) }
                if let error { Text(error).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            }
            Text("Everything runs on your phone; nothing is uploaded. A merge is permanent — iOS has no contacts trash — so back up before you merge.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .task { if authorized && report == nil { scan() } }
        .confirmationDialog("Merge these contacts?",
                            isPresented: Binding(get: { pendingMerge != nil }, set: { if !$0 { pendingMerge = nil } }),
                            titleVisibility: .visible) {
            Button("Merge \(pendingMerge?.count ?? 0) into one", role: .destructive) { if let g = pendingMerge { doMerge(g) }; pendingMerge = nil }
            Button("Cancel", role: .cancel) { pendingMerge = nil }
        } message: {
            Text("Every number and email is kept on one contact; the duplicates are removed. This can't be undone, so make sure you've backed up.")
        }
        .confirmationDialog("Merge all duplicate groups?",
                            isPresented: Binding(get: { pendingMergeAll != nil }, set: { if !$0 { pendingMergeAll = nil } }),
                            titleVisibility: .visible) {
            Button("Merge all \(pendingMergeAll?.count ?? 0) groups", role: .destructive) { if let gs = pendingMergeAll { doMergeAll(gs) }; pendingMergeAll = nil }
            Button("Cancel", role: .cancel) { pendingMergeAll = nil }
        } message: {
            Text("Each group collapses to one contact, keeping every number and email. This can't be undone, so make sure you've backed up.")
        }
        .sheet(item: $tidy) { g in
            NavigationStack {
                ContactsTidySheet(group: g, onChanged: { scan() })
                    .navigationTitle(g.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { tidy = nil } } }
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

    private var backupBar: some View {
        Group {
            if let backupURL {
                ShareLink(item: backupURL) { Label("Share or save the backup", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            } else {
                Button { backup() } label: {
                    HStack { if busy { ProgressView() }; Label("Back up all contacts (.vcf)", systemImage: "arrow.down.doc") }.frame(maxWidth: .infinity)
                }.primaryButton().disabled(busy)
            }
        }
    }

    @ViewBuilder private func reportBody(_ r: ContactsReport) -> some View {
        HStack {
            Text("\(r.total) contacts · \(r.duplicateCount) duplicate\(r.duplicateCount == 1 ? "" : "s")")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Spacer()
            Button { scan() } label: { Label("Rescan", systemImage: "arrow.clockwise") }.textButton().disabled(scanning || busy)
        }

        if r.duplicateGroups.isEmpty {
            Text("No duplicates found.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
        }

        // Merge every duplicate group in one go — each group collapses to a single contact.
        if r.duplicateGroups.count > 1 {
            Button { pendingMergeAll = r.duplicateGroups } label: {
                HStack {
                    if busy { ProgressView().tint(.white) }
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
            TidyGroup(title: "No phone number", icon: "phone.badge.plus", recs: r.noPhone, deletable: false),
            TidyGroup(title: "Only an email", icon: "envelope", recs: r.emailOnly, deletable: false),
            TidyGroup(title: "No name", icon: "person.fill.questionmark", recs: r.noName, deletable: false),
            TidyGroup(title: "Empty — nothing saved", icon: "person.crop.circle.badge.xmark", recs: r.empty, deletable: true),
        ].filter { !$0.recs.isEmpty }
        if !buckets.isEmpty {
            Text("Tidy up").font(HandyFont.bodyStrong)
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
            Text("Every contact has a name and a number. ✓").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }

        if !r.sources.isEmpty {
            Text("Where they're saved").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(r.sources) { s in
                    Text("\(s.name) · \(s.count)").font(HandyFont.micro).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(HandyColor.surface, in: Capsule()).overlay(Capsule().stroke(HandyColor.border, lineWidth: 1))
                }
            }
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

    private func backup() {
        busy = true; error = nil
        Task {
            do {
                let url = try await Task.detached { try ContactsEngine.exportVCard() }.value
                await MainActor.run { backupURL = url; busy = false; HandyHaptics.success() }
            } catch {
                await MainActor.run { self.error = "Couldn't create the backup. Try again."; busy = false }
            }
        }
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
                    ShareLink(item: url) { Label("Share .vcf", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                } else {
                    Button { exportGroup() } label: {
                        HStack { if busy { ProgressView() }; Label("Export (.vcf)", systemImage: "square.and.arrow.up") }.frame(maxWidth: .infinity)
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
            Button("Cancel", role: .cancel) {}
        } message: { Text("They have no name and no number. This can't be undone.") }
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
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) { onDone() }
    }
}

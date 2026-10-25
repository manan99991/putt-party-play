import SwiftUI
import Contacts

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
    }

    private var permissionCard: some View {
        VStack(spacing: HandySpacing.s16) {
            EmptyState(icon: "person.2.fill", line: "Contacts needs access",
                       sub: "To find duplicates and back up, it needs to read your contacts. Nothing is uploaded — it all stays on your phone.")
            Button { Task { authorized = await ContactsEngine.requestAccess(); if authorized { scan() } } } label: {
                Label("Allow contacts access", systemImage: "lock.open").frame(maxWidth: .infinity)
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

        if !r.incomplete.isEmpty {
            Text("Incomplete (\(r.incomplete.count))").font(HandyFont.bodyStrong)
            ForEach(r.incomplete.prefix(20)) { rec in
                HStack {
                    Text(rec.hasName ? rec.name : (rec.numbers.first ?? "(empty)")).font(HandyFont.body).lineLimit(1)
                    Spacer()
                    Text(rec.whyIncomplete).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
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

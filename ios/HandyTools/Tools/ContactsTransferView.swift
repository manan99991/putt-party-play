import SwiftUI
import UniformTypeIdentifiers

/// Move contacts between accounts in three taps: pick where they are, pick where they should go, press the button.
/// Copy is the default and keeps the originals. Move asks first and saves a backup file before it removes anything.
struct ContactsTransferView: View {
    var onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [ContactAccount] = []
    @State private var from: String?
    @State private var to: String?
    @State private var move = false
    @State private var busy = false
    @State private var progress = 0.0
    @State private var outcome: ContactsTransfer.Outcome?
    @State private var backup: URL?
    @State private var confirmMove = false
    @State private var pickFile = false

    private var fromAcc: ContactAccount? { accounts.first { $0.id == from } }
    private var toAcc: ContactAccount? { accounts.first { $0.id == to } }
    private var ready: Bool { from != nil && to != nil && from != to && !busy }

    var body: some View {
        List {
            Section {
                Text("Moving contacts from Gmail to your phone, or the other way? Pick the two places and tap the button. Nothing leaves your phone.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            Section("1. Take contacts from") {
                ForEach(accounts) { a in row(a, selected: from == a.id) { from = a.id; if to == a.id { to = nil } } }
            }
            Section("2. Put them into") {
                ForEach(accounts.filter { $0.id != from }) { a in row(a, selected: to == a.id) { to = a.id } }
                Text("Don't see Gmail? Add it in Settings › Contacts › Accounts › Add Account › Google, and turn Contacts on.")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            Section("3. How") {
                Picker("How", selection: $move) {
                    Text("Copy (keep originals)").tag(false)
                    Text("Move (remove from old)").tag(true)
                }.pickerStyle(.segmented)
                if move { Text("Move removes the originals from the first account once the copies are saved. A backup file is made first.").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            }
            Section {
                Button { move ? (confirmMove = true) : run() } label: {
                    HStack { if busy { ProgressView() }; Text(label).frame(maxWidth: .infinity) }
                }.primaryButton().disabled(!ready).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                if busy { ProgressView(value: progress) }
                Button { pickFile = true } label: { Label("Or add contacts from a .vcf file", systemImage: "doc.badge.plus") }
                    .disabled(to == nil || busy)
                if to == nil { Text("Pick where they should go in step 2 first.").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            }
            if let o = outcome { Section("Done") { result(o) } }
        }
        .navigationTitle("Move contacts").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .task { accounts = ContactsTransfer.accounts() }
        .confirmationDialog("Move contacts?", isPresented: $confirmMove, titleVisibility: .visible) {
            Button("Move \(fromAcc?.count ?? 0) contacts", role: .destructive) { run() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("They are copied into \(toAcc?.title ?? "the new account") first, then removed from \(fromAcc?.title ?? "the old one"). Removing can't be undone. A backup file is saved first.") }
        .fileImporter(isPresented: $pickFile, allowedContentTypes: [UTType(filenameExtension: "vcf") ?? .data, .vCard]) { r in
            guard case .success(let url) = r, let to else { return }
            busy = true; outcome = nil
            Task.detached {
                let o = ContactsTransfer.importVCard(url, to: to)
                await MainActor.run { outcome = o; busy = false; onChanged(); accounts = ContactsTransfer.accounts() }
            }
        }
    }

    private var label: String {
        let n = fromAcc?.count ?? 0
        guard let t = toAcc else { return "Pick two accounts" }
        return "\(move ? "Move" : "Copy") \(n) contact\(n == 1 ? "" : "s") to \(t.name.isEmpty ? t.kind : t.name)"
    }

    private func row(_ a: ContactAccount, selected: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.name.isEmpty ? a.kind : a.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                    Text("\(a.count) contacts · \(a.kind)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? HandyColor.accent : HandyColor.textSecondary)
            }
        }
    }

    @ViewBuilder private func result(_ o: ContactsTransfer.Outcome) -> some View {
        Text("\(o.copied) added").font(HandyFont.bodyStrong)
        if o.alreadyThere > 0 { Text("\(o.alreadyThere) already there, so skipped").font(HandyFont.caption) }
        if o.failed > 0 { Text("\(o.failed) couldn't be added (the account may be read-only). They were left where they are.").font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        if o.removed > 0 { Text("\(o.removed) removed from the old account").font(HandyFont.caption) }
        if let backup { ShareLink(item: backup) { Label("Save the backup file", systemImage: "square.and.arrow.up") } }
    }

    private func run() {
        guard let f = from, let t = to else { return }
        busy = true; outcome = nil; progress = 0
        let mv = move
        Task.detached {
            // A move saves a backup of everything first, so nothing is ever only in the removed copy.
            let b = mv ? (try? ContactsEngine.exportVCard()) : nil
            let o = ContactsTransfer.transfer(from: f, to: t, move: mv) { p in Task { @MainActor in progress = p } }
            await MainActor.run { backup = b; outcome = o; busy = false; onChanged(); accounts = ContactsTransfer.accounts() }
        }
    }
}

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

    private var hasText: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 }

    var body: some View {
        ToolPage(title: "Sorted", subtitle: "Snap a bill, appointment card, form or notice — get what it is, what you owe and the deadline, then add it to your calendar.") {
            HowTo("sorted", [
                "Snap a photo of the letter, bill or card (or paste its text).",
                "Tap Make sense of it — you get what it is, the amount, and the date.",
                "Add it to your calendar in one tap, with a reminder the day before.",
            ])

            inputCard
            if busy { HStack { ProgressView(); Text("Reading it…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }

            if hasText {
                Button { run() } label: { HStack { if working { ProgressView().tint(.white) }; Label(working ? "Thinking…" : "Make sense of it", systemImage: "wand.and.stars") }.frame(maxWidth: .infinity) }
                    .primaryButton().disabled(working)
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let parsed { resultCard(parsed) }

            if !AIEngine.isAvailable {
                LimitNote("Dates and amounts are found on every phone. The plain-English \u{201C}what it is / what to do\u{201D} line uses Apple Intelligence (iPhone 15 Pro or newer).")
            }
            Text("A reading aid, not official advice — always check the original document for the exact terms and deadline.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { if Launch.sample, text.isEmpty { text = "City Water Utility\nAccount 55-2910\nService address: 12 Maple St\nAmount due: $84.20\nPayment due by December 15, 2026\nPlease pay by the due date to avoid a $10 late fee." } }
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
                .overlay(alignment: .topLeading) { if text.isEmpty { Text("Snap or paste the document…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
            HandyFlow(spacing: HandySpacing.s8) {
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Photo", systemImage: "camera.viewfinder") }.compactButton()
                Button("Paste") { if let s = UIPasteboard.general.string { text = s; parsed = nil } }.compactButton()
                if hasText { Button("Clear") { text = ""; parsed = nil; errorText = nil } .textButton() }
            }
        }
    }

    private func resultCard(_ p: SortedEngine.Parsed) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Text(p.kind.uppercased()).font(HandyFont.micro).foregroundStyle(HandyColor.accent).padding(.horizontal, 8).padding(.vertical, 3).background(HandyColor.accentSoft, in: Capsule())
                Spacer()
            }
            Text(p.title).font(HandyFont.cardTitle).frame(maxWidth: .infinity, alignment: .leading)
            Text(p.summary).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            if let amount = p.amount {
                HStack(spacing: HandySpacing.s8) { Image(systemName: "dollarsign.circle.fill").foregroundStyle(HandyColor.accent); Text("Amount").foregroundStyle(HandyColor.textSecondary); Spacer(); Text(amount).font(HandyFont.bodyStrong) }
            }
            if let due = p.due {
                HStack(spacing: HandySpacing.s8) { Image(systemName: "calendar").foregroundStyle(HandyColor.accent); Text("Date").foregroundStyle(HandyColor.textSecondary); Spacer(); Text(SortedEngine.dateString(due)).font(HandyFont.bodyStrong).multilineTextAlignment(.trailing) }
            }
            HStack(spacing: HandySpacing.s8) {
                if let url = icsFile {
                    ShareLink(item: url) { Label("Add to Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
                }
                Button { UIPasteboard.general.string = shareText(p); ClipStore.add(shareText(p)); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if p.due == nil { Text("No clear date found, so there's nothing to calendar — the details above are still yours to copy.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }.cardStyle()
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
        parsed = basic; icsFile = SortedEngine.icsURL(basic)
        HandyHaptics.success()
        Task { @MainActor in
            defer { working = false }
            if let refined = await SortedEngine.aiParse(t) { parsed = refined; icsFile = SortedEngine.icsURL(refined) }
        }
    }
}

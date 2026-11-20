import SwiftUI
import PhotosUI
import Contacts
import VisionKit

/// Business Cards — scan one card or a whole stack (front and back), see each as a contact card you can
/// fix before anything is saved, then save to Contacts (never a duplicate), set a follow-up reminder with
/// where you met, look them up on LinkedIn, or share as a contact file / QR code.
struct BusinessCardsView: View {
    @State private var entries: [CardKit.Entry] = []
    @State private var notCards: [String] = []          // text from pictures that weren't cards
    @State private var picks: [PhotosPickerItem] = []
    @State private var scanning = false
    @State private var reading = false
    @State private var progress: Double = 0
    @State private var twoSided = false
    @State private var place = ""
    @State private var followUp = 7                     // days; 0 = none
    @State private var adding: CNMutableContact?
    @State private var note: String?
    @State private var errorText: String?

    var body: some View {
        ToolPage(title: "Business Cards", subtitle: "Scan cards into real contacts — check every detail first, never a duplicate.", working: reading) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                inputs
                if reading { ToolProgressBar(value: progress, label: "Reading your cards…") }
                if !entries.isEmpty {
                    meetCard
                    if entries.count > 1 {
                        Text(L("Tap ✕ on any card you don't want — it won't be saved.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    ForEach($entries) { $e in
                        CardEditor(entry: $e, onSave: { save(e) }, followUp: followUp,
                                   onRemove: { let id = e.id; withAnimation { entries.removeAll { $0.id == id } } })
                    }
                }
                ForEach(notCards, id: \.self) { t in notACard(t) }
                if let n = note { Label(L(n), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(Color.green) }
                if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onChange(of: picks) { _, items in load(items) }
        .fullScreenCover(isPresented: $scanning) { DocCameraSheet { imgs in scanning = false; read(imgs) }.ignoresSafeArea() }
        .sheet(item: Binding(get: { adding.map { ContactBox(c: $0) } }, set: { adding = $0?.c })) { ContactAddSheet(contact: $0.c) }
        .handoffPhotos("cards") { imgs in read(imgs) }
    }

    private struct ContactBox: Identifiable { let c: CNMutableContact; let id = UUID() }

    private var inputs: some View {
        VStack(spacing: HandySpacing.s8) {
            Button { scanning = true } label: { Label(L("Scan cards with the camera"), systemImage: "camera.viewfinder").frame(maxWidth: .infinity) }
                .primaryButton().disabled(!VNDocumentCameraViewController.isSupported)
            PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .images) {
                Label(L("Choose card photos"), systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
            }.secondaryButton()
            Toggle(L("My cards have a back side — pair them front, back"), isOn: $twoSided).font(HandyFont.caption).tint(HandyColor.accent)
            Text(L("Scan a whole stack in one go — each card becomes its own contact.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private var meetCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Where did you meet?")).font(HandyFont.bodyStrong)
            TextField(L("e.g. HIMSS conference, Chicago (optional)"), text: $place).textFieldStyle(.handy)
            Text(L("Follow-up reminder")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach([(0, "None"), (1, "Tomorrow"), (3, "In 3 days"), (7, "In a week"), (14, "In 2 weeks")], id: \.0) { d, t in
                    HChip(text: L(t), selected: followUp == d) { followUp = d }
                }
            }
            if entries.count > 1 {
                Button { saveAll() } label: { Label("\(L("Save all")) \(entries.count) \(L("to Contacts"))", systemImage: "person.2.badge.plus") }.compactButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func notACard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("This doesn't look like a business card"), systemImage: "questionmark.square.dashed").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.amber)
            Text(L("There's no phone number or email laid out like a card. Here's what it says — copy it, or try a clearer photo of the card.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            Text(text).font(.system(size: 13, design: .monospaced)).lineLimit(8).frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button { Copier.copy(text) } label: { Label(L("Copy text"), systemImage: "doc.on.doc") }.compactButton()
                Button(L("Dismiss")) { notCards.removeAll { $0 == text } }.textButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    // MARK: - Reading

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var imgs: [UIImage] = []
            for it in items { if let d = try? await it.loadTransferable(type: Data.self), let i = UIImage(data: d) { imgs.append(i) } }
            await MainActor.run { picks = []; read(imgs) }
        }
    }

    private func read(_ imgs: [UIImage]) {
        guard !imgs.isEmpty else { return }
        reading = true; progress = 0; errorText = nil; note = nil
        let pair = twoSided
        Task {
            var texts: [(UIImage, String)] = []
            for (i, img) in imgs.enumerated() {
                // Read row by row, so a two-column card's sides stay apart ("Name    Company") and stacked lines line up.
                let box = UncheckedImage(img)
                let t = await Task.detached(priority: .userInitiated) { ChainRunner.rows(DocEngine.recognize(box.image.normalizedUp())) }.value
                texts.append((img, t))
                await MainActor.run { progress = Double(i + 1) / Double(imgs.count) }
            }
            var found: [CardKit.Entry] = [], other: [String] = []
            var i = 0
            while i < texts.count {
                let (img, t) = texts[i]
                if pair, i + 1 < texts.count {
                    let back = texts[i + 1].1
                    let both = t + "\n" + back
                    if CardKit.looksLikeCard(both) {
                        found.append(CardKit.Entry(card: CardKit.merge(DataGrab.card(t), DataGrab.card(back)), raw: both, front: img))
                    } else { other.append(both) }
                    i += 2; continue
                }
                if CardKit.looksLikeCard(t) { found.append(CardKit.Entry(card: DataGrab.card(t), raw: t, front: img)) }
                else if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { other.append(t) }
                i += 1
            }
            await MainActor.run {
                reading = false
                entries += found; notCards += other
                if found.isEmpty, other.isEmpty { errorText = "Couldn't read any words in that — try a sharper photo with the card filling the frame." }
                if !found.isEmpty { HandyHaptics.success() }
            }
        }
    }

    // MARK: - Saving

    private func save(_ e: CardKit.Entry) {
        var entry = e
        entry.note = CardKit.metNote(where: place)
        if let dup = CardKit.existing(entry.card) {
            note = "\(dup.givenName) \(dup.familyName) is already in your Contacts — nothing duplicated.".trimmingCharacters(in: .whitespaces)
            remind(entry); return
        }
        adding = CardKit.contact(entry)     // Apple's own contact sheet: review once more, then Done saves it
        remind(entry)
    }

    private func saveAll() {
        Task {
            let store = CNContactStore()
            let ok = (try? await store.requestAccess(for: .contacts)) ?? false
            await MainActor.run {
                guard ok else { errorText = "Tenzy needs Contacts access to save them all at once — allow it in Settings, or save each card on its own."; return }
                let req = CNSaveRequest(); var added = 0, skipped = 0
                for var e in entries {
                    e.note = CardKit.metNote(where: place)
                    if CardKit.existing(e.card, in: store) != nil { skipped += 1; continue }
                    req.add(CardKit.contact(e), toContainerWithIdentifier: nil); added += 1
                    remind(e)
                }
                do { try store.execute(req); note = "Saved \(added) to Contacts\(skipped > 0 ? " · \(skipped) already there" : "")."; HandyHaptics.success() }
                catch { errorText = "Couldn't save to Contacts — try saving one card at a time." }
            }
        }
    }

    private func remind(_ e: CardKit.Entry) {
        guard followUp > 0, let due = Calendar.current.date(byAdding: .day, value: followUp, to: Date()) else { return }
        let at = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: due) ?? due
        let who = e.card.name.isEmpty ? (e.card.company.isEmpty ? "your new contact" : e.card.company) : e.card.name
        let task = ThinkingEngine.Task(text: "Follow up with \(who) — \(e.note)", actions: ThinkingActions.plan(for: "Follow up with \(who)"), due: at)
        Task { @MainActor in _ = try? await ThinkingReminders.add([task]) }
    }
}

/// One card as an editable contact: photo of the card, every field, and its actions.
private struct CardEditor: View {
    @Binding var entry: CardKit.Entry
    let onSave: () -> Void
    let followUp: Int
    var onRemove: (() -> Void)? = nil
    @State private var showQR = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                if let f = entry.front { Image(uiImage: f).resizable().scaledToFill().frame(width: 84, height: 54).clipShape(RoundedRectangle(cornerRadius: 8)) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.card.name.isEmpty ? L("New contact") : entry.card.name).font(HandyFont.bodyStrong)
                    Text([entry.card.title, entry.card.company].filter { !$0.isEmpty }.joined(separator: " · ")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                Spacer(minLength: 0)
                if let onRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(HandyColor.textSecondary)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Remove this card"))
                    .accessibilityIdentifier("card-remove")
                }
            }
            field("Name", $entry.card.name)
            field("Job title", $entry.card.title)
            field("Company", $entry.card.company)
            ForEach(entry.card.phones.indices, id: \.self) { i in field("Phone", $entry.card.phones[i], keyboard: .phonePad) }
            ForEach(entry.card.emails.indices, id: \.self) { i in field("Email", $entry.card.emails[i], keyboard: .emailAddress) }
            field("Website", $entry.card.website, keyboard: .URL)
            field("Address", $entry.card.address)
            HStack(spacing: HandySpacing.s8) {
                Button { entry.card.phones.append("") } label: { Label(L("Phone"), systemImage: "plus") }.textButton().font(HandyFont.caption)
                Button { entry.card.emails.append("") } label: { Label(L("Email"), systemImage: "plus") }.textButton().font(HandyFont.caption)
            }
            Button { onSave() } label: { Label(L("Save to Contacts"), systemImage: "person.crop.circle.badge.plus").frame(maxWidth: .infinity) }.primaryButton()
            HandyFlow(spacing: HandySpacing.s8) {
                if let u = CardKit.linkedIn(entry.card) { Link(destination: u) { Label(L("Find on LinkedIn"), systemImage: "magnifyingglass") }.compactButton() }
                if let p = entry.card.phones.first(where: { !CardKit.digits($0).isEmpty }), let u = URL(string: "tel:\(CardKit.digits(p))") { Link(destination: u) { Label(L("Call"), systemImage: "phone") }.compactButton() }
                if let m = entry.card.emails.first, let u = URL(string: "mailto:\(m)") { Link(destination: u) { Label(L("Email"), systemImage: "envelope") }.compactButton() }
                ShareLink(item: VCardFile(data: Data(DataGrab.vcard(entry.card).utf8)), preview: SharePreview(entry.card.name.isEmpty ? "Contact" : entry.card.name)) {
                    Label(L("Share contact"), systemImage: "square.and.arrow.up")
                }.compactButton()
                Button { showQR.toggle() } label: { Label(L("QR code"), systemImage: "qrcode") }.compactButton()
            }
            if showQR, let q = CardKit.qr(entry.card) {
                Image(uiImage: q).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 220).frame(maxWidth: .infinity)
                Text(L("Anyone can scan this with their camera to add the contact.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
    }

    private func field(_ label: String, _ text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(L(label)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 78, alignment: .leading)
            TextField(L(label), text: text).keyboardType(keyboard).textInputAutocapitalization(keyboard == .default ? .words : .never)
                .autocorrectionDisabled(keyboard != .default)
        }
        .padding(.vertical, 2)
    }
}

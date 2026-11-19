import SwiftUI

/// The answer when "What is this?" is pointed at writing: what kind of thing it is in plain words, what it says in
/// one line, the photo it came from, and then the right reader working in place — the schedule's names by day
/// ready for Calendar or a spreadsheet, the receipt's total ready to keep, the poster's event ready for Calendar,
/// the card's numbers ready for Contacts. No "Document 71%", no web search for the words on the page.
struct PaperCard: View {
    let read: Paper.Read
    let photo: UIImage?
    @State private var zoom = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                if let photo {
                    Button { zoom = true } label: {
                        Image(uiImage: photo).resizable().scaledToFill().frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }.buttonStyle(.plain).accessibilityLabel(L("See the photo"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label(L("What this is"), systemImage: icon).font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                    Text(L(read.name)).font(HandyFont.title).fixedSize(horizontal: false, vertical: true)
                    if !read.gist.isEmpty {
                        Text(read.gist).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .cardStyle(padding: HandySpacing.s16)

            reader
        }
        .sheet(isPresented: $zoom) { if let photo { ZoomPhoto(image: photo) } }
    }

    private var icon: String {
        switch read.kind {
        case .schedule: return "person.3.sequence"
        case .calendar: return "calendar"
        case .receipt: return "receipt"
        case .menu: return "fork.knife"
        case .label: return "pills"
        case .card: return "person.text.rectangle"
        case .poster: return "megaphone"
        case .bill: return "envelope.open"
        case .lists: return "checklist"
        case .page: return "doc.text"
        }
    }

    @ViewBuilder private var reader: some View {
        switch read.kind {
        case .schedule, .calendar, .lists:
            if let photo { BoardReview(photo: photo) } else { textBox }
        case .receipt:
            ReceiptResult(receipt: DataGrab.receipt(read.text), photo: photo)
        case .poster:
            let e = DataGrab.event(read.text)
            EventCard(event: ICSParse.Event(title: e.title, start: e.start, end: e.end, location: e.location, notes: e.notes, url: e.url.isEmpty ? nil : e.url), primary: true)
            textBox
        case .card, .bill:
            PullDetailsResult(text: read.text)
            textBox
        case .label:
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                ForEach(LabelFirst.parts(read.text), id: \.title) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(p.title)).font(HandyFont.bodyStrong)
                        ForEach(p.lines, id: \.self) { Text($0).font(HandyFont.body).textSelection(.enabled) }
                    }
                }
                Text(L("The label's own words. If anything is unclear, ask a pharmacist.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
        case .menu:
            if let photo {
                Button {
                    ToolHandoff.shared.put(.image(photo), for: "menu")
                    NotificationCenter.default.post(name: .openTool, object: "menu")
                } label: { Label(L("Read it in Menu Assistant"), systemImage: "fork.knife").frame(maxWidth: .infinity) }.primaryButton()
            }
            textBox
        case .page:
            textBox
        }
    }

    /// Everything read, in order — selectable, and one tap to copy.
    private var textBox: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Everything it says")).font(HandyFont.bodyStrong)
            ScrollView {
                Text(read.text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 220).scrollBounceBehavior(.basedOnSize)
            CopyButton(text: read.text)
        }
        .cardStyle(padding: HandySpacing.s12)
    }
}

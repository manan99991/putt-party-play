import SwiftUI

/// How each building block looks: an icon, a colour and one plain sentence about what it does.
extension Block {
    var icon: String {
        switch self {
        case .readText: return "text.viewfinder"
        case .pullReceipt: return "receipt"
        case .summarize: return "text.quote"
        case .shrinkImage: return "arrow.down.right.and.arrow.up.left"
        case .stripLocation: return "location.slash"
        case .cutout: return "person.crop.circle.badge.minus"
        case .enhance: return "wand.and.stars"
        case .convertImage: return "arrow.triangle.2.circlepath"
        case .businessCard: return "person.crop.rectangle"
        case .calendarEvent: return "calendar.badge.plus"
        case .actionItems: return "checklist"
        case .hideSensitive: return "eye.slash"
        case .passportPhoto: return "person.crop.square"
        case .cleanText: return "text.badge.checkmark"
        case .pullDetails: return "link"
        case .makeTable: return "tablecells"
        case .scamCheck: return "shield.lefthalf.filled"
        case .cleanLinks: return "link.badge.plus"
        case .priceCompare: return "tag"
        case .makeQr: return "qrcode"
        case .describe: return "text.below.photo"
        case .identify: return "viewfinder"
        case .photoPdf: return "doc.richtext"
        case .watermark: return "character.textbox"
        case .resizePhoto: return "aspectratio"
        case .stamp: return "signature"
        case .expenseRow: return "dollarsign.circle"
        case .addToList: return "text.badge.plus"
        }
    }
    var tint: Color {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems, .cleanText, .pullDetails, .cleanLinks, .priceCompare, .describe, .identify, .expenseRow: return Color(hex: 0x3B82F6)
        case .shrinkImage, .convertImage, .stripLocation, .resizePhoto: return Color(hex: 0x10B981)
        case .cutout, .enhance, .passportPhoto: return Color(hex: 0xA855F7)
        case .hideSensitive, .scamCheck, .watermark: return Color(hex: 0xF97316)
        case .businessCard, .calendarEvent, .makeTable, .photoPdf, .makeQr, .stamp, .addToList: return Color(hex: 0xEC4899)
        }
    }
    var blurb: String {
        switch self {
        case .readText: return "Reads the words in a photo."
        case .pullReceipt: return "Finds store, date, items and total."
        case .summarize: return "Boils long text down to the key sentences."
        case .shrinkImage: return "Makes a photo fit under a size you pick."
        case .stripLocation: return "Removes where and when a photo was taken."
        case .cutout: return "Lifts the main subject off its background."
        case .enhance: return "Sharpens and balances the photo."
        case .convertImage: return "Saves the photo as JPG, PNG or HEIC."
        case .businessCard: return "Turns card text into a contact file."
        case .calendarEvent: return "Turns event text into a calendar file."
        case .actionItems: return "Pulls out the things someone has to do."
        case .hideSensitive: return "Covers faces and personal numbers."
        case .passportPhoto: return "Crops to a passport or ID photo size."
        case .cleanText: return "Removes extra spaces, blank gaps and repeated lines."
        case .pullDetails: return "Lists every web link, email address and phone number."
        case .makeTable: return "Turns rows of text into a spreadsheet (CSV) file."
        case .scamCheck: return "Says if a message looks like a scam, and why."
        case .cleanLinks: return "Strips the tracking off web links."
        case .priceCompare: return "Compares unit prices and names the best deal."
        case .makeQr: return "Turns text or a link into a QR code."
        case .describe: return "Says what the photo shows."
        case .identify: return "Names the plant, animal, object or barcode."
        case .photoPdf: return "Turns the photo into a searchable PDF."
        case .watermark: return "Writes your words and today's date across it, so a copy can't be misused."
        case .resizePhoto: return "Fits an exact size in pixels, for ID photos and upload forms."
        case .stamp: return "Puts your saved signature, your name and today's date where you placed them."
        case .expenseRow: return "Date, store, total and tax as one row."
        case .addToList: return "Adds the rows to the same sheet every time, one sheet a month."
        }
    }
}

struct BlockBadge: View {
    let block: Block
    var size: CGFloat = 38
    var body: some View {
        Image(systemName: block.icon)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [block.tint, block.tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// What a step produced on the sample, shown under the step while you build.
enum StepPreview {
    case text(String)
    case image(UIImage)
    case file(String)
    case failed(String)
}

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
        case .returnBy: return "arrow.uturn.left.circle"
        case .videoShrink: return "film"
        case .videoStill: return "photo.on.rectangle"
        case .videoMute: return "speaker.slash"
        case .videoAudio: return "waveform"
        case .addToList: return "text.badge.plus"
        case .chatLink: return "bubble.left.and.text.bubble.right"
        case .contactQr: return "person.crop.square.filled.and.at.rectangle"
        case .wifiQr: return "wifi"
        case .videoTrim: return "scissors"
        case .videoGif: return "square.stack.3d.forward.dottedline"
        case .videoRotate: return "rotate.right"
        case .videoVertical: return "rectangle.portrait"
        case .videoCaptions: return "captions.bubble"
        case .speechText: return "waveform.badge.mic"
        case .readAloud: return "speaker.wave.2"
        case .translate: return "globe"
        case .rewrite: return "pencil.and.outline"
        case .readCode: return "qrcode.viewfinder"
        case .pageText: return "safari"
        case .textPdf: return "doc.text"
        case .pdfShrink: return "arrow.down.doc"
        case .pdfLock: return "lock.doc"
        case .pdfPages: return "doc.on.doc"
        case .pdfText: return "doc.text.magnifyingglass"
        }
    }
    var tint: Color {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems, .cleanText, .pullDetails, .cleanLinks, .priceCompare, .describe, .identify, .expenseRow, .chatLink, .speechText, .translate, .rewrite, .readCode, .pageText, .pdfText: return Color(hex: 0x3B82F6)
        case .shrinkImage, .convertImage, .stripLocation, .resizePhoto, .videoShrink, .videoStill, .videoMute, .videoAudio, .videoTrim, .videoGif, .pdfShrink: return Color(hex: 0x10B981)
        case .cutout, .enhance, .passportPhoto, .videoRotate, .videoVertical, .videoCaptions: return Color(hex: 0xA855F7)
        case .hideSensitive, .scamCheck, .watermark, .pdfLock: return Color(hex: 0xF97316)
        case .businessCard, .calendarEvent, .makeTable, .photoPdf, .makeQr, .stamp, .addToList, .contactQr, .wifiQr, .returnBy, .readAloud, .textPdf, .pdfPages: return Color(hex: 0xEC4899)
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
        case .returnBy: return "Puts the last day to return it in your calendar, counted from the receipt's date."
        case .videoShrink: return "Makes a video fit under a size you pick, and leaves its location behind."
        case .videoStill: return "Takes one sharp picture out of the video."
        case .videoMute: return "The same video with no sound."
        case .videoAudio: return "Just the sound, as an audio file."
        case .addToList: return "Adds the rows to the same sheet every time, one sheet a month."
        case .chatLink: return "Opens a WhatsApp chat with a number without saving it as a contact."
        case .contactQr: return "A code another phone scans to save the contact. Only what you typed is included."
        case .wifiQr: return "Finds the network name and password and makes a code guests scan to join. No typing."
        case .videoTrim: return "Keeps the first or last part, for stories and status posts with a time limit."
        case .videoGif: return "Turns the first six seconds into a GIF that plays anywhere."
        case .videoRotate: return "Turns a sideways or upside-down video the right way up."
        case .videoVertical: return "Crops the middle to the tall shape phones and stories use."
        case .videoCaptions: return "Listens to the video and writes what is said along the bottom."
        case .speechText: return "Turns a voice memo or any recording into text. The recording stays on this phone."
        case .readAloud: return "Reads the text into an audio file you can listen to later."
        case .translate: return "Puts the text into the language you pick. Works out the original language itself."
        case .rewrite: return "Rewrites the text clearer, shorter, friendlier or more formal."
        case .readCode: return "Reads what a QR code or barcode says, without opening it."
        case .pageText: return "Opens the link and keeps only the words: no menus, ads or pop-ups."
        case .textPdf: return "Lays the text out as a clean PDF."
        case .pdfShrink: return "Makes a PDF fit under a size you pick."
        case .pdfLock: return "Asks for a password before the PDF opens."
        case .pdfPages: return "Keeps only the pages you list. Leave it empty to keep them all."
        case .pdfText: return "Pulls the words out of a PDF, even a scanned one."
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

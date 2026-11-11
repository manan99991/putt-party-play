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
        }
    }
    var tint: Color {
        switch self {
        case .readText, .pullReceipt, .summarize, .actionItems: return Color(hex: 0x3B82F6)
        case .shrinkImage, .convertImage, .stripLocation: return Color(hex: 0x10B981)
        case .cutout, .enhance, .passportPhoto: return Color(hex: 0xA855F7)
        case .hideSensitive: return Color(hex: 0xF97316)
        case .businessCard, .calendarEvent: return Color(hex: 0xEC4899)
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

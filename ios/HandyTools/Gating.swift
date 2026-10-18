import SwiftUI

/// Free-tier limits, in one place. Free users get the full tool, with a ceiling that upsells to
/// Pro — never a dead "Pro only" wall. Keep these honest and generous enough to be useful.
enum Limits {
    static let freeClips = 15          // Multi-Clipboard saved items
    static let freeAlarms = 3          // Alarm Pro
    static let freeOcrPerDay = 5       // Text from Image
    static let freeTranslatePerDay = 8 // Translate
    static let freeScanPages = 3       // Doc Scanner pages per PDF
    static let freeAiPerDay = 3        // Page-3 AI actions, shared across all AI tools
    static let freeWalletCards = 2     // Card Wallet
    static let freeVideoPerDay = 3     // Video (shrink/trim/convert/mute/audio/GIF jobs)
    static let freeBgRemovePerDay = 5  // Background Remover
    static let freeConvertPerDay = 3   // Image Converter (batches)
    static let freeAudioPerDay = 3     // Audio → Text (recordings)
    static let freePdfOpsPerDay = 3    // PDF Toolkit (jobs)
    static let freeSignPerDay = 3      // Sign & Fill
    static let freeScanPerDay = 5      // Scan (PDF exports)
    static let freeIdPhotoPerDay = 3   // ID / Passport Photo
    static let freeGifPerDay = 3       // GIF Maker
    static let freePhotoStudioPerDay = 4 // Photo Studio edits
    static let freeFitPerDay = 5       // Fit It (exact-size fits)
    static let freeStitchPerDay = 5    // Long Screenshot stitches
    static let freeScrubPerDay = 5     // Privacy Scrubber clean copies
    static let freeStudioPerDay = 6    // Studio edits
}

/// Per-day usage counters that reset at midnight, stored in UserDefaults. Pro is unlimited, so
/// these short-circuit to true for Pro and are never touched. MainActor-isolated because they
/// consult the (MainActor) StoreManager; every caller is a view action already on the main actor.
@MainActor
enum Usage {
    nonisolated(unsafe) private static let d = UserDefaults.standard

    private static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
    private static func key(_ name: String) -> String { "usage.\(name).\(today())" }

    static func count(_ name: String) -> Int { d.integer(forKey: key(name)) }

    /// True if there's room left today (or the user is Pro). Does not consume.
    static func hasRoom(_ name: String, limit: Int) -> Bool {
        if StoreManager.shared.isPremium { return true }
        return count(name) < limit
    }

    /// Consume one unit. Returns true if it was allowed.
    @discardableResult
    static func use(_ name: String, limit: Int) -> Bool {
        if StoreManager.shared.isPremium { return true }
        let c = count(name)
        guard c < limit else { return false }
        d.set(c + 1, forKey: key(name))
        return true
    }

    static func remaining(_ name: String, limit: Int) -> Int {
        if StoreManager.shared.isPremium { return .max }
        return max(0, limit - count(name))
    }
}

/// A small inline banner a free user sees when they hit a limit. Taps open the paywall.
struct LimitReachedBanner: View {
    let message: String
    var body: some View {
        Button { NotificationCenter.default.post(name: .showPaywall, object: nil) } label: {
            HStack(spacing: HandySpacing.s12) {
                Image(systemName: "crown.fill").foregroundStyle(HandyColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message).font(HandyFont.caption).foregroundStyle(HandyColor.textPrimary).multilineTextAlignment(.leading)
                    Text("Tap to go Pro — unlimited").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HandyColor.textSecondary)
            }
            .padding(HandySpacing.s12)
            .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A subtle "x left today" chip free users see on metered tools, so the limit never surprises them.
struct QuotaChip: View {
    @EnvironmentObject var store: StoreManager
    let name: String
    let limit: Int
    var body: some View {
        if !store.isPremium {
            let left = Usage.remaining(name, limit: limit)
            Text("\(left) of \(limit) left today")
                .font(HandyFont.caption)
                .foregroundStyle(left == 0 ? HandyColor.danger : HandyColor.textSecondary)
        }
    }
}

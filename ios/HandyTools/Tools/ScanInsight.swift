import SwiftUI
import PDFKit

/// What the scan did and what's in it, above the PDF: the photo you took beside the clean page, what kind of
/// paper it is ("A letter or bill · due 3 Dec"), how many words are now searchable, and a word you can try
/// searching for — so the person sees it's a real scan, not a picture of a desk in a PDF.
struct ScanInsight: View {
    let pdf: Data
    let original: UIImage?

    private var info: (pages: Int, words: Int, sample: String?, kind: String?) {
        let doc = PDFDocument(data: pdf)
        let text = doc?.string ?? ""
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        // A distinctive word to try: the longest common-looking word that appears more than once.
        var counts: [String: Int] = [:]
        for w in words where w.count >= 6 && w.allSatisfy(\.isLetter) { counts[w.lowercased(), default: 0] += 1 }
        let sample = counts.filter { $0.value >= 2 }.max { ($0.value, $0.key.count) < ($1.value, $1.key.count) }?.key
        let smart = ScanSmart.read(text)
        let kind = smart.kind == .other ? nil : smart.summary
        return (doc?.pageCount ?? 0, words.count, sample, kind)
    }

    var body: some View {
        let i = info
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            if let original, let first = PDFDocument(data: pdf)?.page(at: 0) {
                HStack(spacing: HandySpacing.s8) {
                    pane(original, L("Your photo"))
                    Image(systemName: "arrow.right").foregroundStyle(HandyColor.textSecondary)
                    pane(first.thumbnail(of: CGSize(width: 300, height: 400), for: .cropBox), L("The scan"))
                }
            }
            if let k = i.kind { Label(k, systemImage: "doc.text.magnifyingglass").font(HandyFont.bodyStrong) }
            Label(i.words > 0 ? "\(i.words) \(L("words searchable in any PDF app")) · \(i.pages) \(L(i.pages == 1 ? "page" : "pages"))"
                              : L("No text found — it's saved as a clean picture of the page."),
                  systemImage: i.words > 0 ? "text.magnifyingglass" : "photo")
                .font(HandyFont.caption)
            if let w = i.sample {
                Text("\(L("Try searching it for")) “\(w)”").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            Text(L("Straightened to the page's edges, paper whitened, text darkened.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }

    private func pane(_ img: UIImage, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(uiImage: img).resizable().scaledToFit().frame(height: 140).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
    }
}

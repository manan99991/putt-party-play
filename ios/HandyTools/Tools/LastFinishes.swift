import SwiftUI
import AVFoundation

/// A table read from a photo: the grid itself, how many rows and columns, then a real spreadsheet that opens in
/// Numbers or Excel (or the CSV). Same as the File Opener's table view.
struct TableFinishCard: View {
    let csv: Data
    var name = "Table"
    private var rows: [[String]] {
        (String(data: csv, encoding: .utf8) ?? "").split(whereSeparator: \.isNewline).map { RunningList.fields(String($0)) }
    }
    var body: some View {
        let r = rows
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("\(max(0, r.count - 1)) \(L("rows")) · \(r.map(\.count).max() ?? 0) \(L("columns"))", systemImage: "tablecells").font(HandyFont.bodyStrong)
            DataGrid(rows: r).frame(height: min(360, CGFloat(r.count) * 34 + 20)).clipShape(RoundedRectangle(cornerRadius: 10))
            if let x = XLSXWriter.workbook(rows: r, sheetName: String(name.prefix(30))) {
                ShareLink(item: XLSXFile(data: x), preview: SharePreview("\(name).xlsx")) {
                    Label(L("Open in Numbers or Excel"), systemImage: "tablecells.badge.ellipsis").frame(maxWidth: .infinity)
                }.primaryButton()
            }
            HStack(spacing: HandySpacing.s8) {
                CopyButton(text: r.map { $0.joined(separator: "\t") }.joined(separator: "\n"), title: "Copy (pastes as a table)")
                ShareLink(item: csv, preview: SharePreview("\(name).csv")) { Label("CSV", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("table-finish")
    }
}

/// A cleaned link: where it really goes, what tracking was taken off, then Open / Copy / Share.
struct LinkFinishCard: View {
    let cleaned: String
    var original: String?
    private var removed: [String] {
        guard let o = original.flatMap({ URLComponents(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }) else { return [] }
        let kept = Set((URLComponents(string: cleaned)?.queryItems ?? []).map(\.name))
        return (o.queryItems ?? []).map(\.name).filter { !kept.contains($0) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(L("Clean link"), systemImage: "link").font(HandyFont.bodyStrong)
            if let u = URL(string: cleaned.trimmingCharacters(in: .whitespacesAndNewlines)), u.scheme != nil { LinkSafetyPanel(url: u) }
            Text(cleaned).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
            let gone = removed
            Label(gone.isEmpty ? L("No tracking found — the link was already clean.") : "\(L("Tracking taken off:")) \(gone.prefix(6).joined(separator: ", "))",
                  systemImage: gone.isEmpty ? "checkmark.seal" : "eye.slash.fill")
                .font(HandyFont.caption).foregroundStyle(gone.isEmpty ? HandyColor.textSecondary : Color.green)
                .accessibilityIdentifier("link-removed")
            if let u = URL(string: cleaned.trimmingCharacters(in: .whitespacesAndNewlines)), u.scheme?.hasPrefix("http") == true {
                Link(destination: u) { Label(L("Open"), systemImage: "safari").frame(maxWidth: .infinity) }.primaryButton()
            }
            HStack(spacing: HandySpacing.s8) {
                CopyButton(text: cleaned)
                ShareLink(item: cleaned) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("link-finish")
    }
}

/// The best deal on a shelf: the winner big with its price per unit, then the rest in order, and the photo.
struct DealFinishCard: View {
    let text: String
    var photo: UIImage?
    private var lines: [String] { text.split(whereSeparator: \.isNewline).map(String.init) }
    var body: some View {
        let l = lines
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let first = l.first {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L("Best deal"), systemImage: "trophy.fill").font(HandyFont.caption.weight(.bold)).foregroundStyle(Color.green)
                    Text(first.replacingOccurrences(of: "Best deal: ", with: "")).font(.system(size: 22, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("deal-winner")
            }
            if l.count > 1 {
                Text(L("Then, cheapest per unit first")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(Array(l.dropFirst().enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top) { Text("\(i + 2).").monospacedDigit().foregroundStyle(HandyColor.textSecondary); Text(s) }.font(HandyFont.body)
                }
            }
            if let photo { Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 180).clipShape(RoundedRectangle(cornerRadius: 10)) }
            HStack(spacing: HandySpacing.s8) {
                CopyButton(text: text)
                ShareLink(item: text) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("deal-finish")
    }
}

/// A still from a video: the sharpest frame Tenzy picked, a slider to choose any other moment, then Photos / Copy / Share.
struct StillFinishCard: View {
    let video: URL?
    @State var image: UIImage
    @State private var at: Double = 0
    @State private var length: Double = 0
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).frame(maxHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) { if loading { BusySpinner().padding(8) } }
            if video != nil, length > 0 {
                Text("\(L("Pick another moment")) · \(VideoFacts.clock(at))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                Slider(value: $at, in: 0...max(0.1, length - 0.05)) { editing in if !editing { grab() } }
                    .tint(HandyColor.accent).accessibilityIdentifier("still-moment")
            }
            if let d = image.jpegData(compressionQuality: 0.95) {
                KeepShare([.data(d, name: "Still", ext: "jpg")], tool: "Still", record: false)
                PhotoLandingRow(data: d, image: image)
            }
            Text("\(Int(image.size.width * image.scale))×\(Int(image.size.height * image.scale))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("still-finish")
        .task { if let v = video, let d = try? await AVURLAsset(url: v).load(.duration) { length = d.seconds.isFinite ? d.seconds : 0 } }
    }

    private func grab() {
        guard let v = video else { return }
        loading = true
        let t = at
        Task {
            let img = await VideoEngine.thumbnail(v, at: t, maxDim: 1920)
            await MainActor.run { loading = false; if let img { image = img } }
        }
    }
}

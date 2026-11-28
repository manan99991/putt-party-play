import SwiftUI
import AVFoundation

/// A table read from a photo: the grid itself, how many rows and columns, then a real spreadsheet that opens in
/// Numbers or Excel (or the CSV). Same as the File Opener's table view.
struct TableFinishCard: View {
    let csv: Data
    var name = "Table"
    // Worked out once, not on every redraw: the rows, the copy text and the two files. Building the workbook
    // inside `body` re-zipped it on every redraw, and the grid sat in a scroll box inside the page's own
    // scroll — opening and closing the Share sheet redrew both and left the whole screen blank (27 Nov report).
    @State private var rows: [[String]]
    @State private var xlsxURL: URL?
    @State private var csvURL: URL?
    @State private var showAll = false
    private static let firstRows = 8
    private static let maxColumns = 5
    /// UI tests only (-sharelink): the old SwiftUI ShareLink, so the test can show the bug and the fix side by side.
    private static let useShareLink = Launch.uitest && Launch.args.contains("-sharelink")

    init(csv: Data, name: String = "Table") {
        self.csv = csv
        self.name = name
        _rows = State(initialValue: TableFinishCard.parse(csv))
    }

    static func parse(_ csv: Data) -> [[String]] {
        (String(data: csv, encoding: .utf8) ?? "").split(whereSeparator: \.isNewline).map { RunningList.fields(String($0)) }
    }

    private var fileBase: String {
        let n = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined().trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "Table" : String(n.prefix(60))
    }

    var body: some View {
        let r = rows
        let cols = r.map(\.count).max() ?? 0
        let shownCols = min(cols, Self.maxColumns)
        let items = Array(r.dropFirst())
        let shown = showAll ? items : Array(items.prefix(Self.firstRows))
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label("\(items.count) \(L("rows")) · \(cols) \(L("columns"))", systemImage: "tablecells").font(HandyFont.bodyStrong)
            // The table fits the screen: every column side by side, nothing to scroll sideways.
            VStack(spacing: 0) {
                if let head = r.first { tableRow(head, cols: shownCols, header: true) }
                ForEach(Array(shown.enumerated()), id: \.offset) { _, row in tableRow(row, cols: shownCols, header: false) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(HandyColor.border, lineWidth: 1))
            .accessibilityIdentifier("table-grid")
            if cols > shownCols {
                Text(String(format: L("+%d more columns in the spreadsheet"), cols - shownCols)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
            if items.count > Self.firstRows {
                Button { withAnimation(.easeOut(duration: HandyMotion.fast)) { showAll.toggle() } } label: {
                    Label(showAll ? L("Show fewer rows") : String(format: L("Show all %d rows"), items.count),
                          systemImage: showAll ? "chevron.up" : "chevron.down").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.accent)
                .accessibilityIdentifier("table-show-all")
            }
            if let x = xlsxURL {
                if Self.useShareLink {
                    ShareLink(item: x) {
                        Label(L("Open in Numbers or Excel"), systemImage: "tablecells.badge.ellipsis").frame(maxWidth: .infinity)
                    }.primaryButton().accessibilityIdentifier("table-xlsx")
                } else {
                    ShareFilesButton(x) {
                        Label(L("Open in Numbers or Excel"), systemImage: "tablecells.badge.ellipsis").frame(maxWidth: .infinity)
                    }.primaryButton().accessibilityIdentifier("table-xlsx")
                }
            } else {
                Button {} label: { Label(L("Open in Numbers or Excel"), systemImage: "tablecells.badge.ellipsis").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(true)
            }
            HStack(spacing: HandySpacing.s8) {
                CopyButton(text: r.map { $0.joined(separator: "\t") }.joined(separator: "\n"), title: "Copy (pastes as a table)")
                if let c = csvURL {
                    if Self.useShareLink {
                        ShareLink(item: c) { Label("CSV", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                            .secondaryButton().accessibilityIdentifier("table-csv")
                    } else {
                        ShareFilesButton(c) { Label("CSV", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                            .secondaryButton().accessibilityIdentifier("table-csv")
                    }
                }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("table-finish")
        .task(id: csv) { await makeFiles() }
    }

    private func tableRow(_ row: [String], cols: Int, header: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<max(cols, 1), id: \.self) { i in
                Text(i < row.count ? row[i] : "")
                    .font(header ? HandyFont.caption.weight(.semibold) : HandyFont.caption)
                    .lineLimit(header ? 2 : 3)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .overlay(alignment: .trailing) { if i < cols - 1 { Rectangle().fill(HandyColor.border).frame(width: 0.5) } }
            }
        }
        .background(header ? HandyColor.surface : Color.clear)
        .overlay(alignment: .bottom) { Rectangle().fill(HandyColor.border).frame(height: 0.5) }
    }

    /// The two files, written once off the main thread, with the tool's own name — so the Share sheet just hands them on.
    private func makeFiles() async {
        let r = rows, base = fileBase, sheet = String(name.prefix(30)), data = csv
        let urls: (URL?, URL?) = await Task.detached(priority: .userInitiated) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("table-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var x: URL?, c: URL?
            if let w = XLSXWriter.workbook(rows: r, sheetName: sheet) {
                let u = dir.appendingPathComponent("\(base).xlsx")
                if (try? w.write(to: u)) != nil { x = u }
            }
            let cu = dir.appendingPathComponent("\(base).csv")
            if (try? data.write(to: cu)) != nil { c = cu }
            return (x, c)
        }.value
        xlsxURL = urls.0
        csvURL = urls.1
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
            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).frame(maxHeight: 380).opensFullSize(image)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) { if loading { BusySpinner().padding(8) } }
            if video != nil, length > 0 {
                Text("\(L("Pick another moment")) · \(VideoFacts.clock(at))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).monospacedDigit()
                Slider(value: $at, in: 0...max(0.1, length - 0.05)) { editing in if !editing { grab() } }
                    .tint(HandyColor.accent).accessibilityIdentifier("still-moment")
            }
            if let d = ImageBytes.jpeg(image, quality: 0.95) {
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

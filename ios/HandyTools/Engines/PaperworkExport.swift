import Foundation
import SwiftUI

/// Paperwork, ready for tax time (or an accountant, or a claim): one .zip with a spreadsheet of every receipt
/// for the year, a spreadsheet of the bills and letters, and every receipt photo named by date and store.
/// Built on the phone from Warranty & Receipts and Sorted. The list-making is pure and unit-tested.
enum PaperworkExport {
    static func csv(_ rows: [[String]]) -> String {
        rows.map { $0.map(ContactBook.csvCell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
    static func day(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
    static func year(_ d: Date) -> Int { Calendar(identifier: .gregorian).component(.year, from: d) }

    /// "2026-03-14 Costco.jpg" — sortable, readable, safe on Windows and Mac. Repeats get " 2", " 3".
    static func photoName(_ r: Receipt, taken: inout Set<String>) -> String {
        let store = r.store.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "-").trimmingCharacters(in: .whitespaces)
        let base = "\(day(r.purchaseDate ?? r.addedAt)) \(store.isEmpty ? "Receipt" : String(store.prefix(40)))"
        var name = base + ".jpg", n = 2
        while taken.contains(name.lowercased()) { name = "\(base) \(n).jpg"; n += 1 }
        taken.insert(name.lowercased())
        return name
    }

    static func receiptRows(_ rs: [Receipt], photoNames: [UUID: String]) -> [[String]] {
        [["Date", "Store", "Total", "Items", "Warranty ends", "Return by", "Note", "Photo"]] +
        rs.sorted { ($0.purchaseDate ?? $0.addedAt) < ($1.purchaseDate ?? $1.addedAt) }.map { r in
            [day(r.purchaseDate ?? r.addedAt), r.store, r.total, r.items.joined(separator: "; "), day(r.warrantyEnds), day(r.returnBy), r.note,
             photoNames[r.id].map { "Receipt photos/" + $0 } ?? ""]
        }
    }

    static func letterRows(_ ls: [SortedLetters.Item]) -> [[String]] {
        [["Due", "Kind", "What", "Amount", "Status", "Added"]] +
        ls.sorted { ($0.due ?? $0.added) < ($1.due ?? $1.added) }.map {
            [day($0.due), $0.kind, $0.title, $0.amount ?? "", $0.done ? "Paid / done" : "Open", day($0.added)]
        }
    }

    /// Which years have anything in them, newest first.
    static func years(receipts: [Receipt], letters: [SortedLetters.Item]) -> [Int] {
        Array(Set(receipts.map { year($0.purchaseDate ?? $0.addedAt) } + letters.map { year($0.due ?? $0.added) })).sorted(by: >)
    }

    struct Pack { let url: URL; let receipts: Int; let letters: Int; let photos: Int }

    static func make(year y: Int, receipts all: [Receipt], letters allL: [SortedLetters.Item], photo: (Receipt) -> Data?) -> Pack? {
        let rs = all.filter { year($0.purchaseDate ?? $0.addedAt) == y }
        let ls = allL.filter { year($0.due ?? $0.added) == y }
        guard !rs.isEmpty || !ls.isEmpty else { return nil }
        var taken = Set<String>(), names: [UUID: String] = [:], files: [ZipWriter.Item] = []
        for r in rs { if let d = photo(r) { let n = photoName(r, taken: &taken); names[r.id] = n; files.append(.init(name: "Receipt photos/" + n, data: d)) } }
        let bom = Data([0xEF, 0xBB, 0xBF])
        if !rs.isEmpty { files.insert(.init(name: "Receipts \(y).csv", data: bom + Data(csv(receiptRows(rs, photoNames: names)).utf8)), at: 0) }
        if !ls.isEmpty { files.insert(.init(name: "Bills and letters \(y).csv", data: bom + Data(csv(letterRows(ls)).utf8)), at: 0) }
        let readme = """
        Paperwork for \(y) — made with Tenzy on \(day(Date())).
        Receipts: \(rs.count) (spreadsheet + \(names.count) photos in "Receipt photos").
        Bills and letters: \(ls.count).
        Open the .csv files in Excel, Numbers or Google Sheets.
        """
        files.insert(.init(name: "Read me.txt", data: Data(readme.utf8)), at: 0)
        guard case .success(let zip) = ZipWriter.zip(files, keepPaths: true) else { return nil }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("Paperwork \(y).zip")
        try? FileManager.default.removeItem(at: u)
        guard (try? zip.write(to: u)) != nil else { return nil }
        return Pack(url: u, receipts: rs.count, letters: ls.count, photos: names.count)
    }
}

/// "Tax-season export" — pick a year, get one tidy .zip. Shown in Warranty & Receipts and in Sorted.
struct PaperworkExportCard: View {
    @ObservedObject var receipts: ReceiptStore
    @State private var letters: [SortedLetters.Item] = []
    @State private var year = PaperworkExport.year(Date())
    @State private var pack: PaperworkExport.Pack?
    @State private var working = false
    @State private var problem: String?

    private var years: [Int] {
        let y = PaperworkExport.years(receipts: receipts.receipts, letters: letters)
        return y.isEmpty ? [PaperworkExport.year(Date())] : y
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(L("Paperwork for the year"), systemImage: "archivebox").font(HandyFont.bodyStrong)
            Text(L("One .zip for taxes, your accountant or a claim: a spreadsheet of every receipt, one of your bills and letters, and every receipt photo named by date and store."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            Picker(L("Year"), selection: $year) { ForEach(years, id: \.self) { Text(String($0)).tag($0) } }.pickerStyle(.segmented)
                .onChange(of: year) { _, _ in pack = nil }
            if let p = pack {
                Label("\(p.receipts) \(L("receipts")) · \(p.letters) \(L("bills and letters")) · \(p.photos) \(L("photos"))", systemImage: "checkmark.circle.fill")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                ShareLink(item: p.url) { Label("\(L("Save or send")) \(p.url.lastPathComponent)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
            } else {
                Button { make() } label: {
                    HStack { if working { ProgressView() }; Label(L("Make the paperwork pack"), systemImage: "doc.zipper") }.frame(maxWidth: .infinity)
                }.secondaryButton().disabled(working).accessibilityIdentifier("paperwork-make")
            }
            if let problem { Text(L(problem)).font(HandyFont.caption).foregroundStyle(HandyColor.amber) }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear { letters = SortedStore().items; if !years.contains(year) { year = years[0] } }
    }

    private func make() {
        working = true; problem = nil
        let rs = receipts.receipts, ls = letters, y = year
        let urls = Dictionary(uniqueKeysWithValues: rs.map { ($0.id, receipts.imageURL($0)) })
        Task {
            let p = await Task.detached(priority: .userInitiated) {
                PaperworkExport.make(year: y, receipts: rs, letters: ls) { r in urls[r.id].flatMap { try? Data(contentsOf: $0) } }
            }.value
            await MainActor.run {
                working = false
                if let p { pack = p } else { problem = "Nothing saved for \(y) yet — add receipts in Warranty & Receipts or letters in Sorted." }
            }
        }
    }
}

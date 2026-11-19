import XCTest
import UIKit
@testable import HandyTools

/// Accuracy on REAL photos, not drawn test images. CI downloads public sets into $REAL_PHOTOS before this runs
/// (skipped when it isn't set, e.g. in the main gate) and publishes the report this writes to $ACCURACY_REPORT:
/// every photo, what Tenzy read, what the right answer is, and a score per field. The score is ratcheted: it
/// may never fall below the last good run (`floor`), so a change that makes reading worse fails here.
///
/// Receipts: ICDAR 2019 SROIE (real shop receipts, crumpled, faded, skewed) with their official answers for the
/// shop, date and total.
final class RealPhotoAccuracyTests: XCTestCase {

    private var root: URL? { ProcessInfo.processInfo.environment["REAL_PHOTOS"].map { URL(fileURLWithPath: $0) } }
    private var reportURL: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["ACCURACY_REPORT"] ?? NSTemporaryDirectory() + "accuracy.txt") }

    // MARK: scoring helpers

    static func words(_ s: String) -> Set<String> {
        Set(s.uppercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 && !["SDN", "BHD", "THE", "AND"].contains($0) })
    }
    /// Share of the right answer's words that Tenzy got (0…1).
    static func overlap(_ got: String, _ want: String) -> Double {
        let w = words(want); guard !w.isEmpty else { return 1 }
        return Double(w.intersection(words(got)).count) / Double(w.count)
    }
    /// "25/12/2018", "25-12-18", "2018-12-25" → day, month, year (two-digit years as 20xx).
    static func dmy(_ s: String) -> (Int, Int, Int)? {
        let n = s.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        guard n.count >= 3 else { return nil }
        if n[0] > 31 { return (n[2], n[1], n[0]) }
        return (n[0], n[1], n[2] < 100 ? 2000 + n[2] : n[2])
    }

    // MARK: receipts

    func testReceiptsReadLikeTheOfficialAnswers() throws {
        guard let root else { throw XCTSkip("REAL_PHOTOS not set — runs in the accuracy job") }
        let img = root.appendingPathComponent("sroie/data/img"), key = root.appendingPathComponent("sroie/data/key")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: img.path))?.filter { $0.hasSuffix(".jpg") }.sorted() ?? []
        XCTAssertFalse(files.isEmpty, "no receipts downloaded")
        var lines: [String] = ["RECEIPTS (SROIE)\tshop\tdate\ttotal\t| read: shop / date / total\t| right: shop / date / total"]
        var shop = 0.0, date = 0, total = 0, n = 0
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "UTC")
        for name in files {
            let stem = (name as NSString).deletingPathExtension
            guard let photo = UIImage(contentsOfFile: img.appendingPathComponent(name).path),
                  let kd = try? Data(contentsOf: key.appendingPathComponent(stem + ".json")),
                  let k = try? JSONSerialization.jsonObject(with: kd) as? [String: String] else { continue }
            let text = ChainRunner.rows(DocEngine.recognize(photo))
            let r = DataGrab.receipt(text)
            n += 1
            let s = Self.overlap(r.merchant, k["company"] ?? ""); shop += s
            var dOK = false
            if let d = r.date, let want = Self.dmy(k["date"] ?? "") {
                let c = Calendar(identifier: .gregorian).dateComponents(in: TimeZone.current, from: d)
                // Some receipts print month first; count either reading of an ambiguous day/month as right.
                dOK = c.year == want.2 && ((c.day == want.0 && c.month == want.1) || (c.day == want.1 && c.month == want.0))
            }
            if dOK { date += 1 }
            let tOK = r.total.map { abs($0 - (Double(k["total"]?.replacingOccurrences(of: ",", with: "") ?? "") ?? -1)) < 0.005 } ?? false
            if tOK { total += 1 }
            let shownDate = r.date.map { d -> String in f.dateFormat = "dd/MM/yyyy"; return f.string(from: d) } ?? "—"
            lines.append("\(stem)\t\(String(format: "%.2f", s))\t\(dOK ? 1 : 0)\t\(tOK ? 1 : 0)\t| \(r.merchant) / \(shownDate) / \(r.total.map { String(format: "%.2f", $0) } ?? "—")\t| \(k["company"] ?? "") / \(k["date"] ?? "") / \(k["total"] ?? "")")
        }
        guard n > 0 else { return }
        let sShop = shop / Double(n), sDate = Double(date) / Double(n), sTotal = Double(total) / Double(n)
        lines.insert(String(format: "SCORE receipts n=%d shop=%.3f date=%.3f total=%.3f", n, sShop, sDate, sTotal), at: 0)
        Self.append(lines, to: reportURL)
        lines.forEach { print("ACC| " + $0) }      // also in the log, in case the report file can't be written
        // Ratchet: raise these as the reader improves; never lower them.
        XCTAssertGreaterThanOrEqual(sTotal, Self.floor["receipt.total"] ?? 0)
        XCTAssertGreaterThanOrEqual(sDate, Self.floor["receipt.date"] ?? 0)
        XCTAssertGreaterThanOrEqual(sShop, Self.floor["receipt.shop"] ?? 0)
    }

    /// The last good scores. Start at 0 for the first measured run, then set to just under each new best.
    static let floor: [String: Double] = ["receipt.total": 0, "receipt.date": 0, "receipt.shop": 0]

    static func append(_ lines: [String], to url: URL) {
        let text = lines.joined(separator: "\n") + "\n\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(text.utf8)); try? h.close() }
        else { try? text.write(to: url, atomically: true, encoding: .utf8) }
    }
}

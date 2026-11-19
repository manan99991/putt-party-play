import XCTest
import UIKit
@testable import HandyTools

/// The real photos Manan tested with (receipts, posters, Chinese menus, whiteboards), scored against the right
/// answers in ios/RealPhotos/golden.json. The photos are decrypted by CI into $REAL_PHOTOS/private; skipped when
/// they aren't there. Every line of the report says what Tenzy read and what it should have read.
final class PrivatePhotoAccuracyTests: XCTestCase {

    private var dir: URL? {
        guard let r = ProcessInfo.processInfo.environment["REAL_PHOTOS"] else { return nil }
        let u = URL(fileURLWithPath: r).appendingPathComponent("private")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
    private var golden: [String: Any]? {
        guard let p = ProcessInfo.processInfo.environment["GOLDEN"], let d = try? Data(contentsOf: URL(fileURLWithPath: p)) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }
    private var reportURL: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["ACCURACY_REPORT"] ?? NSTemporaryDirectory() + "accuracy.txt") }

    private func photo(_ name: String) -> UIImage? { dir.flatMap { UIImage(contentsOfFile: $0.appendingPathComponent(name).path) } }
    private func report(_ lines: [String]) {
        RealPhotoAccuracyTests.append(lines, to: reportURL)
        lines.forEach { print("ACC| " + $0) }
    }
    private func setUpOrSkip() throws -> [String: Any] {
        guard dir != nil, let g = golden else { throw XCTSkip("private photos not decrypted — runs in the accuracy job") }
        return g
    }
    static func norm(_ s: String) -> String { s.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") }

    // MARK: receipts

    func testReceipts() throws {
        let g = try setUpOrSkip()
        var lines = ["MY RECEIPTS\tfile\tshop\tdate\ttotal\titems\t| read"]
        var score = 0.0, n = 0.0
        for case let e as [String: Any] in g["receipts"] as? [Any] ?? [] {
            let file = e["file"] as? String ?? ""
            guard let img = photo(file) else { lines.append("MISSING \(file)"); continue }
            let r = DataGrab.receipt(ChainRunner.rows(DocEngine.recognize(img)))
            let shop = RealPhotoAccuracyTests.overlap(r.merchant, e["merchant"] as? String ?? "")
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let dOK = r.date.map { (e["date"] as? [String] ?? []).contains(f.string(from: $0)) } ?? false
            let tOK = r.total.map { abs($0 - (e["total"] as? Double ?? -1)) < 0.005 } ?? false
            let want = e["items"] as? [[Any]] ?? []
            let got = want.filter { w in r.items.contains { abs($0.1 - (w[1] as? Double ?? -1)) < 0.005 && RealPhotoAccuracyTests.overlap($0.0, w[0] as? String ?? "") >= 0.6 } }.count
            let items = want.isEmpty ? 1 : Double(got) / Double(want.count)
            score += (shop + (dOK ? 1 : 0) + (tOK ? 1 : 0) + items) / 4; n += 1
            lines.append("\(file)\t\(String(format: "%.2f", shop))\t\(dOK ? 1 : 0)\t\(tOK ? 1 : 0)\t\(got)/\(want.count)\t| \(r.merchant) / \(r.date.map { f.string(from: $0) } ?? "—") / \(r.total.map { String(format: "%.2f", $0) } ?? "—") / \(r.items.map { "\($0.0)=\($0.1)" }.joined(separator: "; "))")
        }
        lines.insert(String(format: "SCORE my-receipts %.3f", n > 0 ? score / n : 0), at: 0)
        report(lines)
    }

    // MARK: posters

    func testPosters() throws {
        let g = try setUpOrSkip()
        var lines = ["MY POSTERS\tfile\ttitle\tdate\ttime\tplace\tlink\t| read"]
        var score = 0.0, n = 0.0
        let cal = Calendar.current
        for case let e as [String: Any] in g["posters"] as? [Any] ?? [] {
            let file = e["file"] as? String ?? ""
            guard let img = photo(file) else { lines.append("MISSING \(file)"); continue }
            let ocr = DocEngine.recognize(img)
            let text = ChainRunner.rows(ocr)
            let ev = DataGrab.event(text, heights: Dictionary(ocr.map { ($0.text, $0.box.height) }, uniquingKeysWith: max))
            let title = Self.norm(ev.title) == Self.norm(e["title"] as? String ?? "") ? 1.0 : RealPhotoAccuracyTests.overlap(ev.title, e["title"] as? String ?? "") * 0.5
            let c = ev.start.map { cal.dateComponents([.month, .day, .hour, .minute], from: $0) }
            let dOK = c?.month == e["month"] as? Int && c?.day == e["day"] as? Int
            let tOK = c.map { String(format: "%02d:%02d", $0.hour ?? -1, $0.minute ?? -1) } == e["start"] as? String
            let place = RealPhotoAccuracyTests.overlap(ev.location, e["location"] as? String ?? "")
            let link = Self.norm(ev.url).contains(Self.norm(e["url"] as? String ?? "")) ? 1.0 : 0
            score += (title + (dOK ? 1 : 0) + (tOK ? 1 : 0) + place + link) / 5; n += 1
            lines.append("\(file)\t\(String(format: "%.2f", title))\t\(dOK ? 1 : 0)\t\(tOK ? 1 : 0)\t\(String(format: "%.2f", place))\t\(Int(link))\t| \(ev.title) / \(ev.start.map { "\($0)" } ?? "—") / \(ev.location) / \(ev.url)")
        }
        lines.insert(String(format: "SCORE my-posters %.3f", n > 0 ? score / n : 0), at: 0)
        report(lines)
    }

    // MARK: menus

    func testMenus() throws {
        let g = try setUpOrSkip()
        var lines = ["MY MENUS\tfile\tdishes found\tright price\t| missed"]
        var score = 0.0, n = 0.0
        for case let e as [String: Any] in g["menus"] as? [Any] ?? [] {
            let file = e["file"] as? String ?? ""
            guard let img = photo(file) else { lines.append("MISSING \(file)"); continue }
            let items = MenuReader.parse(MenuReader.lines(from: MenuReader.read(img))).filter { !$0.note }
            let want = e["dishes"] as? [[Any]] ?? []
            var hit = 0, missed: [String] = []
            for w in want {
                let name = w[0] as? String ?? "", price = Double(w[1] as? Int ?? -1)
                if items.contains(where: { $0.name.contains(name) && $0.price == price }) { hit += 1 } else { missed.append("\(name) \(Int(price))") }
            }
            let count = min(1, Double(items.filter { $0.price != nil }.count) / Double(e["minDishes"] as? Int ?? 1))
            let s = (Double(hit) / Double(max(1, want.count)) + count) / 2
            score += s; n += 1
            lines.append("\(file)\t\(items.filter { $0.price != nil }.count)\t\(hit)/\(want.count)\t| \(missed.joined(separator: ", "))")
        }
        lines.insert(String(format: "SCORE my-menus %.3f", n > 0 ? score / n : 0), at: 0)
        report(lines)
    }

    // MARK: whiteboards (how much of the board is read at all; the planner's own scoring comes with it)

    func testBoardsAreRead() throws {
        let g = try setUpOrSkip()
        var lines = ["MY BOARDS\tfile\twords read\t| missed"]
        var score = 0.0, n = 0.0
        for case let e as [String: Any] in g["boards"] as? [Any] ?? [] {
            let file = e["file"] as? String ?? ""
            guard let img = photo(file) else { lines.append("MISSING \(file)"); continue }
            let text = Self.norm(ChainRunner.rows(DocEngine.recognize(img)))
            var want = (e["items"] as? [String] ?? []) + (e["sections"] as? [String] ?? []) + (e["out"] as? [String] ?? [])
            want += (e["events"] as? [[Any]] ?? []).compactMap { $0.first as? String }
            want += (e["rows"] as? [[String]] ?? []).flatMap { [$0[0], $0[2]] }
            let missed = want.filter { !text.contains(Self.norm($0)) }
            let s = want.isEmpty ? 1 : 1 - Double(missed.count) / Double(want.count)
            score += s; n += 1
            lines.append("\(file)\t\(want.count - missed.count)/\(want.count)\t| \(missed.prefix(25).joined(separator: ", "))")
        }
        lines.insert(String(format: "SCORE my-boards-read %.3f", n > 0 ? score / n : 0), at: 0)
        report(lines)
    }

    // MARK: whiteboards understood (sections, items, ticks, events, people) — the rules path CI can run

    func testBoardsAreUnderstood() throws {
        let g = try setUpOrSkip()
        var lines = ["MY BOARDS UNDERSTOOD\tfile\tkind\titems\tdone\tevents\tpeople\t| missed"]
        var score = 0.0, n = 0.0
        let cal = Calendar.current
        for case let e as [String: Any] in g["boards"] as? [Any] ?? [] {
            let file = e["file"] as? String ?? ""
            guard let img = photo(file) else { lines.append("MISSING \(file)"); continue }
            let b = Understand.parse(DocEngine.recognize(img.normalizedUp()), now: Date())
            let texts = b.tasks.map { Self.norm($0.text) } + b.events.map { Self.norm($0.title) } + b.people.map { Self.norm($0.what) }
            func found(_ w: String) -> Bool { let k = Self.norm(w); return texts.contains { $0.contains(k) || (k.count > 6 && k.contains($0) && $0.count > 4) } }
            let items = e["items"] as? [String] ?? []
            let missed = items.filter { !found($0) }
            let iScore = items.isEmpty ? 1 : 1 - Double(missed.count) / Double(items.count)
            let done = e["done"] as? [String] ?? []
            let dScore = done.isEmpty ? 1 : Double(done.filter { d in b.tasks.contains { $0.done && Self.norm($0.text).contains(Self.norm(d)) } }.count) / Double(done.count)
            let evs = e["events"] as? [[Any]] ?? []
            let eScore = evs.isEmpty ? 1 : Double(evs.filter { w in b.events.contains { ev in
                Self.norm(ev.title).contains(Self.norm(w[0] as? String ?? "")) && ev.date.map { cal.component(.day, from: $0) } == w[1] as? Int } }.count) / Double(evs.count)
            let rows = e["rows"] as? [[String]] ?? []
            let pScore = rows.isEmpty ? 1 : Double(rows.filter { r in b.people.contains { Self.norm($0.person) == Self.norm(r[0]) && $0.day == r[1] && Self.norm($0.what).contains(Self.norm(r[2])) } }.count) / Double(rows.count)
            let s = (iScore + dScore + eScore + pScore) / 4
            score += s; n += 1
            lines.append("\(file)\t\(b.kind.rawValue)\t\(String(format: "%.2f", iScore))\t\(String(format: "%.2f", dScore))\t\(String(format: "%.2f", eScore))\t\(String(format: "%.2f", pScore))\t| \(missed.prefix(20).joined(separator: ", "))")
            lines.append("   read: " + b.tasks.prefix(40).map { ($0.done ? "✓" : "") + $0.text + ($0.section.isEmpty ? "" : " [\($0.section)]") }.joined(separator: " | "))
            if !b.events.isEmpty { lines.append("   events: " + b.events.map { "\($0.title) @ \($0.date.map { "\($0)" } ?? "—")" }.joined(separator: " | ")) }
            if !b.people.isEmpty { lines.append("   people: " + b.people.prefix(30).map { "\($0.person) \($0.day): \($0.what)" }.joined(separator: " | ")) }
        }
        lines.insert(String(format: "SCORE my-boards-understood %.3f", n > 0 ? score / n : 0), at: 0)
        report(lines)
    }
}

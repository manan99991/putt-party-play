import XCTest
import UIKit
import CoreImage
@testable import HandyTools

/// The hard cases, scored every build (runs in the accuracy job; skipped elsewhere):
///  • CORD v2 receipts: crumpled, curved, Indonesian prices with dot thousands ("60.000"), every item and total.
///  • IAM handwriting: how much of real handwriting the reader gets right, character by character.
///  • Real-world camera trouble on Manan's own photos: tilted, in perspective, blurry, dim, glare, low-res,
///    heavy JPEG — the same right answers must still come out.
///  • Generated business cards and posters in many layouts and fonts, each with its exact right answer,
///    also put through the camera trouble.
final class ToughPhotoTests: XCTestCase {
    private var root: URL? { ProcessInfo.processInfo.environment["REAL_PHOTOS"].map { URL(fileURLWithPath: $0) } }
    private var reportURL: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["ACCURACY_REPORT"] ?? NSTemporaryDirectory() + "accuracy.txt") }
    private func report(_ lines: [String]) { RealPhotoAccuracyTests.append(lines, to: reportURL); lines.forEach { print("ACC| " + $0) } }
    private func need() throws -> URL { guard let root else { throw XCTSkip("runs in the accuracy job") }; return root }

    // MARK: camera trouble

    enum Trouble: String, CaseIterable { case tilt, perspective, blur, dim, glare, lowres, jpeg }

    static func trouble(_ img: UIImage, _ t: Trouble) -> UIImage {
        guard let cg = img.normalizedUp().cgImage else { return img }
        let ci = CIImage(cgImage: cg), ext = ci.extent
        let ctx = CIContext()
        var out: CIImage
        switch t {
        case .tilt:
            out = ci.transformed(by: CGAffineTransform(translationX: ext.midX, y: ext.midY).rotated(by: 0.12).translatedBy(x: -ext.midX, y: -ext.midY))
                .composited(over: CIImage(color: .gray).cropped(to: ext.insetBy(dx: -ext.width * 0.1, dy: -ext.height * 0.1)))
        case .perspective:
            let w = ext.width, h = ext.height
            out = ci.applyingFilter("CIPerspectiveTransform", parameters: [
                "inputTopLeft": CIVector(x: w * 0.08, y: h * 0.95), "inputTopRight": CIVector(x: w * 0.9, y: h),
                "inputBottomLeft": CIVector(x: 0, y: h * 0.05), "inputBottomRight": CIVector(x: w, y: 0)])
                .composited(over: CIImage(color: .gray).cropped(to: ext))
        case .blur: out = ci.clampedToExtent().applyingGaussianBlur(sigma: Double(max(1.2, ext.width / 900))).cropped(to: ext)
        case .dim: out = ci.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -1.6]).applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.75])
        case .glare:
            let g = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter": CIVector(x: ext.width * 0.7, y: ext.height * 0.6), "inputRadius0": ext.width * 0.05,
                                                                    "inputRadius1": ext.width * 0.35, "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 0.85), "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 0)])!.outputImage!.cropped(to: ext)
            out = g.composited(over: ci)
        case .lowres:
            let s = min(1, 700 / max(ext.width, ext.height))
            out = ci.transformed(by: CGAffineTransform(scaleX: s, y: s))
        case .jpeg:
            if let d = UIImage(cgImage: cg).jpegData(compressionQuality: 0.12), let j = UIImage(data: d) { return j }
            out = ci
        }
        guard let r = ctx.createCGImage(out, from: out.extent.isInfinite ? ext : out.extent) else { return img }
        return UIImage(cgImage: r)
    }

    // MARK: CORD receipts

    static func money(_ s: String) -> Double? {
        let digits = s.filter { $0.isNumber }
        return digits.isEmpty ? nil : Double(digits)
    }

    func testCORDReceipts() throws {
        let dir = try need().appendingPathComponent("cord")
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
        guard !files.isEmpty else { throw XCTSkip("CORD not downloaded") }
        var lines = ["CORD RECEIPTS\tfile\ttotal\titems\t| read total / right total | missed items"]
        var tScore = 0.0, iScore = 0.0, n = 0.0
        for f in files {
            let stem = (f as NSString).deletingPathExtension
            guard let img = UIImage(contentsOfFile: dir.appendingPathComponent(f).path),
                  let gd = try? Data(contentsOf: dir.appendingPathComponent(stem + ".json")),
                  let gt = try? JSONSerialization.jsonObject(with: gd) as? [String: Any] else { continue }
            let r = DataGrab.receipt(ChainRunner.rows(DocEngine.recognize(img)))
            let wantTotal = ((gt["total"] as? [String: Any])?["total_price"] as? String).flatMap(Self.money)
            // Read totals as whole numbers of the smallest unit: "60.000" and 60000 match, "60.00" and 60 match.
            let tOK: Bool = {
                guard let w = wantTotal, let t = r.total else { return false }
                return [t, t * 1000, t * 100].contains { abs($0 - w) < 0.5 }
            }()
            var menu: [[String: Any]] = []
            if let m = gt["menu"] as? [[String: Any]] { menu = m } else if let m = gt["menu"] as? [String: Any] { menu = [m] }
            let want = menu.compactMap { m -> (String, Double)? in
                guard let nm = m["nm"] as? String, let p = (m["price"] as? String).flatMap(Self.money) else { return nil }
                return (nm, p)
            }
            let hit = want.filter { w in r.items.contains { abs($0.1 - w.1) < 0.5 || abs($0.1 * 1000 - w.1) < 0.5 || abs($0.1 * 100 - w.1) < 0.5 } }
            let missed = want.filter { w in !hit.contains { $0.0 == w.0 } }.map { "\($0.0) \(Int($0.1))" }
            if tOK { tScore += 1 }
            iScore += want.isEmpty ? 1 : Double(hit.count) / Double(want.count); n += 1
            lines.append("\(stem)\t\(tOK ? 1 : 0)\t\(hit.count)/\(want.count)\t| \(r.total.map { String($0) } ?? "—") / \(wantTotal.map { String(Int($0)) } ?? "—") | \(missed.prefix(6).joined(separator: ", "))")
        }
        lines.insert(String(format: "SCORE cord n=%.0f total=%.3f items=%.3f", n, tScore / max(1, n), iScore / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: handwriting

    static func distance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }; if b.isEmpty { return a.count }
        var prev = Array(0...b.count), cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count { cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    func testHandwritingIsRead() throws {
        let dir = try need().appendingPathComponent("hand")
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
        guard !files.isEmpty else { throw XCTSkip("handwriting not downloaded") }
        var lines = ["HANDWRITING (IAM lines)\tfile\tcharacters right\t| read / written"]
        var total = 0.0, n = 0.0
        for f in files {
            let stem = (f as NSString).deletingPathExtension
            guard let img = UIImage(contentsOfFile: dir.appendingPathComponent(f).path),
                  let want = try? String(contentsOf: dir.appendingPathComponent(stem + ".txt"), encoding: .utf8) else { continue }
            let got = DocEngine.recognize(img).map(\.text).joined(separator: " ")
            let a = Array(got.lowercased()), b = Array(want.lowercased())
            let acc = max(0, 1 - Double(Self.distance(a, b)) / Double(max(1, b.count)))
            total += acc; n += 1
            if acc < 0.85 { lines.append("\(stem)\t\(String(format: "%.2f", acc))\t| \(got) / \(want)") }
        }
        lines.insert(String(format: "SCORE handwriting n=%.0f characters=%.3f", n, total / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: Manan's photos under camera trouble

    func testMyPhotosSurviveCameraTrouble() throws {
        let r = try need().appendingPathComponent("private")
        guard let gp = ProcessInfo.processInfo.environment["GOLDEN"], let gd = try? Data(contentsOf: URL(fileURLWithPath: gp)),
              let g = try? JSONSerialization.jsonObject(with: gd) as? [String: Any], FileManager.default.fileExists(atPath: r.path) else { throw XCTSkip("private photos not decrypted") }
        var lines = ["MY PHOTOS UNDER CAMERA TROUBLE\ttrouble\treceipt totals\tposter dates\tmenu dishes"]
        var all = 0.0, n = 0.0
        for t in Trouble.allCases {
            var rt = 0.0, rn = 0.0, pt = 0.0, pn = 0.0, mt = 0.0, mn = 0.0
            for case let e as [String: Any] in g["receipts"] as? [Any] ?? [] {
                guard let img = UIImage(contentsOfFile: r.appendingPathComponent(e["file"] as? String ?? "").path) else { continue }
                let rec = DataGrab.receipt(ChainRunner.rows(DocEngine.recognize(Self.trouble(img, t))))
                rn += 1; if let tot = rec.total, abs(tot - (e["total"] as? Double ?? -1)) < 0.005 { rt += 1 }
            }
            for case let e as [String: Any] in g["posters"] as? [Any] ?? [] {
                guard let img = UIImage(contentsOfFile: r.appendingPathComponent(e["file"] as? String ?? "").path) else { continue }
                let ocr = DocEngine.recognize(Self.trouble(img, t))
                let ev = DataGrab.event(ChainRunner.rows(ocr), heights: Dictionary(ocr.map { ($0.text, $0.box.height) }, uniquingKeysWith: max))
                let c = ev.start.map { Calendar.current.dateComponents([.month, .day], from: $0) }
                pn += 1; if c?.month == e["month"] as? Int, c?.day == e["day"] as? Int { pt += 1 }
            }
            for case let e as [String: Any] in g["menus"] as? [Any] ?? [] {
                guard let img = UIImage(contentsOfFile: r.appendingPathComponent(e["file"] as? String ?? "").path) else { continue }
                let items = MenuReader.parse(MenuReader.lines(from: MenuReader.read(Self.trouble(img, t))))
                let want = e["dishes"] as? [[Any]] ?? []
                let hit = want.filter { w in items.contains { $0.name.contains(w[0] as? String ?? "§") && $0.price == Double(w[1] as? Int ?? -1) } }.count
                mn += 1; mt += Double(hit) / Double(max(1, want.count))
            }
            let s = (rt / max(1, rn) + pt / max(1, pn) + mt / max(1, mn)) / 3
            all += s; n += 1
            lines.append(String(format: "\t%@\t%.0f/%.0f\t%.0f/%.0f\t%.2f", t.rawValue, rt, rn, pt, pn, mt / max(1, mn)))
        }
        lines.insert(String(format: "SCORE camera-trouble %.3f", all / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: generated business cards

    struct CardTruth { let name, title, company, phone, email, site, street, city: String }
    static let people: [CardTruth] = [
        CardTruth(name: "Henrietta Mitchell", title: "Creative Director", company: "Studio Salford", phone: "+44 161 496 0732", email: "henrietta@studiosalford.co.uk", site: "www.studiosalford.co.uk", street: "12 Chapel Street", city: "Salford M3 5JZ"),
        CardTruth(name: "Rajesh Kumar", title: "Senior Sales Manager", company: "Brightline Logistics Pvt Ltd", phone: "+91 98201 45678", email: "rajesh.kumar@brightline.in", site: "brightline.in", street: "4th Floor, Nirlon Park", city: "Mumbai 400063"),
        CardTruth(name: "Ana Lucía Ortega", title: "Attorney at Law", company: "Ortega & Vidal Abogados", phone: "+34 912 345 678", email: "aortega@ortegavidal.es", site: "ortegavidal.es", street: "Calle de Serrano 41", city: "28001 Madrid"),
        CardTruth(name: "Wei Zhang", title: "Lead Engineer", company: "Northwind Robotics Inc.", phone: "(415) 555-0199", email: "wei@northwindrobotics.com", site: "northwindrobotics.com", street: "500 Howard Street, Suite 300", city: "San Francisco, CA 94105"),
        CardTruth(name: "Olivia Brennan", title: "Realtor", company: "Prairie Home Realty", phone: "630-555-0142", email: "olivia@prairiehome.com", site: "www.prairiehome.com", street: "1520 Ogden Ave", city: "Naperville, IL 60540"),
        CardTruth(name: "Dr. Samuel Okafor", title: "Dental Surgeon", company: "Bright Smile Clinic", phone: "+234 803 555 0101", email: "s.okafor@brightsmile.ng", site: "brightsmile.ng", street: "12 Admiralty Way", city: "Lekki, Lagos"),
    ]

    /// A 3.5×2 in card at 600 px wide in one of several real-world layouts.
    static func renderCard(_ c: CardTruth, layout: Int) -> UIImage {
        let size = CGSize(width: 1050, height: 600)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let dark = layout == 3
            (dark ? UIColor(red: 0.1, green: 0.12, blue: 0.2, alpha: 1) : UIColor(white: 0.98, alpha: 1)).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let ink: UIColor = dark ? .white : UIColor(white: 0.12, alpha: 1)
            func draw(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ weight: UIFont.Weight = .regular, right: Bool = false, color: UIColor? = nil, serif: Bool = false) {
                var font = UIFont.systemFont(ofSize: size, weight: weight)
                if serif, let d = font.fontDescriptor.withDesign(.serif) { font = UIFont(descriptor: d, size: size) }
                let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color ?? ink]
                let w = (s as NSString).size(withAttributes: a).width
                (s as NSString).draw(at: CGPoint(x: right ? x - w : x, y: y), withAttributes: a)
            }
            switch layout {
            case 0: // classic: name top-left, details bottom-left
                draw(c.company.uppercased(), 60, 50, 30, .heavy, color: .systemBlue)
                draw(c.name, 60, 200, 56, .bold); draw(c.title, 60, 270, 32)
                draw(c.phone, 60, 390, 28); draw(c.email, 60, 430, 28); draw(c.site, 60, 470, 28)
                draw("\(c.street), \(c.city)", 60, 520, 24)
            case 1: // two columns: name left, contact right
                draw(c.name, 60, 80, 54, .bold, serif: true); draw(c.title, 60, 150, 30, serif: true); draw(c.company, 60, 190, 30, .semibold, serif: true)
                draw(c.phone, 990, 330, 27, right: true); draw(c.email, 990, 370, 27, right: true); draw(c.site, 990, 410, 27, right: true)
                draw(c.street, 990, 470, 25, right: true); draw(c.city, 990, 505, 25, right: true)
            case 2: // centered with a logo block
                UIColor.systemOrange.setFill(); ctx.fill(CGRect(x: 470, y: 40, width: 110, height: 110))
                let mid: (String, CGFloat, CGFloat, UIFont.Weight) -> Void = { s, y, f, w in
                    let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: f, weight: w)]
                    let width = (s as NSString).size(withAttributes: a).width
                    draw(s, (size.width - width) / 2, y, f, w)
                }
                mid(c.company, 165, 30, .semibold); mid(c.name, 230, 50, .bold); mid(c.title, 295, 28, .regular)
                mid("\(c.phone)  ·  \(c.email)", 400, 26, .regular); mid(c.site, 445, 26, .regular); mid("\(c.street), \(c.city)", 495, 23, .regular)
            default: // dark card, labelled lines
                draw(c.name, 70, 70, 52, .bold); draw(c.title + " | " + c.company, 70, 140, 28)
                draw("T  " + c.phone, 70, 300, 28); draw("E  " + c.email, 70, 345, 28); draw("W  " + c.site, 70, 390, 28)
                draw("A  " + c.street + ", " + c.city, 70, 440, 25)
            }
        }
    }

    func testGeneratedCardsUnderTrouble() throws {
        _ = try need()
        var lines = ["GENERATED CARDS\tcard\tlayout\ttrouble\tname\ttitle\tcompany\tphone\temail\tsite\taddress\t| read"]
        var score = 0.0, n = 0.0
        let troubles: [Trouble?] = [nil, .tilt, .perspective, .blur, .glare, .lowres]
        for (pi, p) in Self.people.enumerated() {
            for layout in 0..<4 {
                for t in troubles {
                    var img = Self.renderCard(p, layout: layout)
                    if let t { img = Self.trouble(img, t) }
                    let c = DataGrab.card(ChainRunner.rows(DocEngine.recognize(img)))
                    let digits: (String) -> String = { $0.filter(\.isNumber) }
                    let checks = [
                        RealPhotoAccuracyTests.overlap(c.name, p.name) >= 0.99,
                        RealPhotoAccuracyTests.overlap(c.title, p.title) >= 0.99,
                        RealPhotoAccuracyTests.overlap(c.company, p.company) >= 0.75,
                        c.phones.contains { digits($0).hasSuffix(String(digits(p.phone).suffix(9))) },
                        c.emails.map { $0.lowercased() }.contains(p.email.lowercased()),
                        c.website.lowercased().contains(p.site.lowercased().replacingOccurrences(of: "www.", with: "")),
                        RealPhotoAccuracyTests.overlap(c.address, p.street + " " + p.city) >= 0.6,
                    ]
                    let s = Double(checks.filter { $0 }.count) / Double(checks.count)
                    score += s; n += 1
                    if s < 1 {
                        lines.append("\t\(pi)\t\(layout)\t\(t?.rawValue ?? "clean")\t" + checks.map { $0 ? "1" : "0" }.joined(separator: "\t")
                                     + "\t| \(c.name) / \(c.title) / \(c.company) / \(c.phones.joined(separator: ",")) / \(c.emails.joined(separator: ",")) / \(c.website) / \(c.address)")
                    }
                }
            }
        }
        lines.insert(String(format: "SCORE generated-cards n=%.0f %.3f", n, score / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: generated posters

    struct PosterTruth { let title: String; let lines: [String]; let month: Int; let day: Int; let hour: Int; let minute: Int; let place: String }
    static let posters: [PosterTruth] = [
        PosterTruth(title: "Spring Book Fair", lines: ["Saturday, April 18", "10 AM – 4 PM", "Naperville Public Library", "200 W Jefferson Ave", "Free entry · Kids' corner"], month: 4, day: 18, hour: 10, minute: 0, place: "Naperville Public Library"),
        PosterTruth(title: "Jazz Night", lines: ["FRI 12.06", "Doors 7:30pm", "The Blue Room, 41 Canal St", "Tickets $25 at bluroom.com"], month: 6, day: 12, hour: 19, minute: 30, place: "The Blue Room, 41 Canal St"),
        PosterTruth(title: "Charity 5K Run", lines: ["Sunday 9 August", "Start 08:00", "Riverside Park, Gate B", "Register at run4good.org"], month: 8, day: 9, hour: 8, minute: 0, place: "Riverside Park, Gate B"),
        PosterTruth(title: "Diwali Mela", lines: ["Oct 24 · 5:00 PM onwards", "Community Center Hall", "Food stalls · Dance · Fireworks"], month: 10, day: 24, hour: 17, minute: 0, place: "Community Center Hall"),
    ]

    static func renderPoster(_ p: PosterTruth, style: Int) -> UIImage {
        let size = CGSize(width: 900, height: 1270)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let bgs: [UIColor] = [.systemTeal, UIColor(red: 0.12, green: 0.1, blue: 0.2, alpha: 1), .systemYellow, .white]
            bgs[style % bgs.count].setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let ink: UIColor = style % 4 == 1 ? .white : .black
            let tf = UIFont.systemFont(ofSize: style % 2 == 0 ? 96 : 84, weight: .black)
            (p.title as NSString).draw(in: CGRect(x: 60, y: 140, width: 780, height: 420), withAttributes: [.font: tf, .foregroundColor: ink])
            var y: CGFloat = 640
            for l in p.lines {
                (l as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 40, weight: .semibold), .foregroundColor: ink]); y += 70
            }
            ("shutterstock" as NSString).draw(at: CGPoint(x: 500, y: 1150), withAttributes: [.font: UIFont.systemFont(ofSize: 44, weight: .bold), .foregroundColor: ink.withAlphaComponent(0.25)])
        }
    }

    func testGeneratedPostersUnderTrouble() throws {
        _ = try need()
        var lines = ["GENERATED POSTERS\tposter\tstyle\ttrouble\ttitle\tdate\ttime\tplace\t| read"]
        var score = 0.0, n = 0.0
        for (pi, p) in Self.posters.enumerated() {
            for style in 0..<4 {
                for t in [nil, Trouble.tilt, .perspective, .blur, .dim, .lowres] as [Trouble?] {
                    var img = Self.renderPoster(p, style: style)
                    if let t { img = Self.trouble(img, t) }
                    let ocr = DocEngine.recognize(img)
                    let ev = DataGrab.event(ChainRunner.rows(ocr), heights: Dictionary(ocr.map { ($0.text, $0.box.height) }, uniquingKeysWith: max))
                    let c = ev.start.map { Calendar.current.dateComponents([.month, .day, .hour, .minute], from: $0) }
                    let checks = [PrivatePhotoAccuracyTests.norm(ev.title) == PrivatePhotoAccuracyTests.norm(p.title),
                                  c?.month == p.month && c?.day == p.day,
                                  c?.hour == p.hour && c?.minute == p.minute,
                                  RealPhotoAccuracyTests.overlap(ev.location, p.place) >= 0.6]
                    let s = Double(checks.filter { $0 }.count) / 4
                    score += s; n += 1
                    if s < 1 { lines.append("\t\(pi)\t\(style)\t\(t?.rawValue ?? "clean")\t" + checks.map { $0 ? "1" : "0" }.joined(separator: "\t") + "\t| \(ev.title) / \(ev.start.map { "\($0)" } ?? "—") / \(ev.location)") }
                }
            }
        }
        lines.insert(String(format: "SCORE generated-posters n=%.0f %.3f", n, score / max(1, n)), at: 0)
        report(lines)
    }
}

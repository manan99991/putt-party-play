import XCTest
import UIKit
import PDFKit
import AVFoundation
import ImageIO
@testable import HandyTools

/// What each photo tool actually hands the user, checked on real photos (runs in the QA lab; skipped elsewhere).
/// Every check measures the OUTPUT again, independently of what the tool says about itself.
///  • Passport: the head and eye line in the finished photo, re-measured, must sit inside each country's limits,
///    the background must be plain, and the file the right size — on a close selfie and on bad versions of it.
///  • Fit It: every real photo lands under the size asked for, still opens, and keeps a usable size.
///  • Cut-out (stickers): a person is lifted cleanly — background see-through, the person solid.
final class ToolOutputQualityTests: XCTestCase {
    private var root: URL? { ProcessInfo.processInfo.environment["REAL_PHOTOS"].map { URL(fileURLWithPath: $0) } }
    private var reportURL: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["ACCURACY_REPORT"] ?? NSTemporaryDirectory() + "accuracy.txt") }
    private func report(_ lines: [String]) { RealPhotoAccuracyTests.append(lines, to: reportURL); lines.forEach { print("ACC| " + $0) } }

    private func privatePhotos(_ prefix: String? = nil) throws -> [(String, UIImage)] {
        guard let root else { throw XCTSkip("runs in the QA lab") }
        let dir = root.appendingPathComponent("private")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
            .filter { prefix == nil || $0.hasPrefix(prefix!) }
        let out = names.compactMap { n in UIImage(contentsOfFile: dir.appendingPathComponent(n).path).map { (n, $0) } }
        guard !out.isEmpty else { throw XCTSkip("private photos not decrypted") }
        return out
    }

    /// A smaller head in a bigger, busier frame — the usual phone selfie taken at arm's length.
    static func farther(_ img: UIImage) -> UIImage {
        let s = img.size
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: s.width * 1.8, height: s.height * 1.8), format: fmt).image { ctx in
            UIColor(red: 0.55, green: 0.6, blue: 0.5, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: CGSize(width: s.width * 1.8, height: s.height * 1.8)))
            UIColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: s.height * 1.1, width: s.width * 1.8, height: s.height * 0.7))
            img.draw(in: CGRect(x: s.width * 0.4, y: s.height * 0.35, width: s.width, height: s.height))
        }
    }

    // MARK: passport

    func testPassportPhotosMeetEachCountrysRules() throws {
        let faces = try privatePhotos("face-")
        var lines = ["PASSPORT\tphoto\tcountry\tvariant\thead mm (limits)\teyes mm (limits)\tbackground\tsize\tscore\t| what failed"]
        var good = 0.0, n = 0.0
        for (name, face) in faces {
            let variants: [(String, UIImage)] = [("as taken", face), ("tilted", ToughPhotoTests.trouble(face, .tilt)), ("dim", ToughPhotoTests.trouble(face, .dim)),
                                                 ("low-res", ToughPhotoTests.trouble(face, .lowres)), ("farther away", Self.farther(face))]
            for spec in PassportPhoto.specs {
                for (v, img) in variants {
                    n += 1
                    guard let made = PassportPhoto.make(img, spec: spec), let cg = made.image.cgImage else {
                        lines.append("\(name)\t\(spec.id)\t\(v)\t—\t—\t—\t—\t—\t| no photo made"); continue
                    }
                    // Re-measure the finished photo ourselves.
                    var fails: [String] = []
                    let sizeOK = abs(CGFloat(cg.width) - spec.px.width) <= 1 && abs(CGFloat(cg.height) - spec.px.height) <= 1
                    if !sizeOK { fails.append("file is \(cg.width)×\(cg.height), should be \(Int(spec.px.width))×\(Int(spec.px.height))") }
                    var headText = "—", eyeText = "—"
                    if let f = PassportPhoto.analyze(cg) {
                        let head = Double(f.chin.y - f.crown.y) / spec.pxPerMM
                        headText = String(format: "%.1f (%@–%@)", head, PassportPhoto.fmt(spec.head.lowerBound), PassportPhoto.fmt(spec.head.upperBound))
                        // Allow 1 mm for the measuring itself.
                        if head < spec.head.lowerBound - 1 || head > spec.head.upperBound + 1 { fails.append("head \(String(format: "%.1f", head)) mm") }
                        if let eyes = spec.eyes {
                            let e = Double(spec.px.height - f.eyeY) / spec.pxPerMM
                            eyeText = String(format: "%.1f (%@–%@)", e, PassportPhoto.fmt(eyes.lowerBound), PassportPhoto.fmt(eyes.upperBound))
                            if e < eyes.lowerBound - 1 || e > eyes.upperBound + 1 { fails.append("eyes \(String(format: "%.1f", e)) mm") }
                        }
                        if abs(f.roll) > 3 { fails.append("head still tilted \(Int(f.roll))°") }
                    } else { fails.append("no face found in the finished photo") }
                    // Background: the top corners must be plain and close to the country's colour (unless the
                    // country asks for unaltered photos, where the background is left as it was).
                    var bgText = "kept"
                    if made.options.background {
                        let px = Self.pixels(cg, at: [CGPoint(x: 6, y: 6), CGPoint(x: cg.width - 7, y: 6)])
                        let want = spec.background == .white ? 255.0 : 235.0
                        let off = px.map { abs($0 - want) }.max() ?? 255
                        bgText = off < 18 ? "plain" : "off by \(Int(off))"
                        if off >= 18 { fails.append("background not plain") }
                    }
                    if fails.isEmpty { good += 1 }
                    lines.append("\(name)\t\(spec.id)\t\(v)\t\(headText)\t\(eyeText)\t\(bgText)\t\(sizeOK ? "ok" : "wrong")\t\(made.score)\t| \(fails.joined(separator: "; "))")
                }
            }
        }
        lines.insert(String(format: "SCORE passport n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    /// Mean of R, G, B at each point (top-left origin).
    static func pixels(_ cg: CGImage, at points: [CGPoint]) -> [Double] {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return points.map { p in
            let x = min(max(Int(p.x), 0), w - 1), y = min(max(Int(p.y), 0), h - 1)
            let o = (y * w + x) * 4
            return (Double(buf[o]) + Double(buf[o + 1]) + Double(buf[o + 2])) / 3
        }
    }

    static func alpha(_ cg: CGImage, at points: [CGPoint]) -> [Int] {
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return points.map { p in Int(buf[(min(max(Int(p.y), 0), h - 1) * w + min(max(Int(p.x), 0), w - 1)) * 4 + 3]) }
    }

    // MARK: Fit It

    func testFitItLandsUnderTheLimitAndKeepsThePhotoUsable() async throws {
        let photos = try privatePhotos()
        var lines = ["FIT IT\tphoto\ttarget\tgot\tlong side\t| problem"]
        var good = 0.0, n = 0.0
        for (name, img) in photos {
            for (target, minSide) in [(100_000, 600), (500_000, 1000)] {
                n += 1
                let d = await SizeTarget.image(img, targetBytes: target)
                var fails: [String] = []
                let out = d.flatMap { UIImage(data: $0) }
                if d == nil { fails.append("nothing made") }
                if let d, d.count > target { fails.append("over the limit") }
                if d != nil, out == nil { fails.append("won't open") }
                let side = out.map { Int(max($0.size.width * $0.scale, $0.size.height * $0.scale)) } ?? 0
                let original = Int(max(img.size.width * img.scale, img.size.height * img.scale))
                if out != nil, side < min(minSide, original) { fails.append("shrunk to \(side) px — too small to read") }
                if fails.isEmpty { good += 1 }
                lines.append("\(name)\t\(target / 1000) KB\t\(d.map { "\($0.count / 1000) KB" } ?? "—")\t\(side)\t| \(fails.joined(separator: "; "))")
            }
        }
        lines.insert(String(format: "SCORE fitit n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: cut-out (stickers, Studio)

    func testCutoutLiftsAPersonCleanly() throws {
        let faces = try privatePhotos("face-")
        var lines = ["CUT-OUT\tphoto\tvariant\tbackground clear\tperson solid\t| problem"]
        var good = 0.0, n = 0.0
        for (name, face) in faces {
            for (v, img) in [("as taken", face), ("farther away", Self.farther(face)), ("dim", ToughPhotoTests.trouble(face, .dim))] {
                n += 1
                guard let cut = ImageStudio.cutout(img), let cg = cut.cgImage else {
                    lines.append("\(name)\t\(v)\t—\t—\t| no cut-out (subject lifting may not run in the simulator)"); continue
                }
                let w = CGFloat(cg.width), h = CGFloat(cg.height)
                let corners = Self.alpha(cg, at: [CGPoint(x: 3, y: 3), CGPoint(x: w - 4, y: 3)])
                let centre = Self.alpha(cg, at: [CGPoint(x: w / 2, y: h * 0.45)])
                let clear = (corners.max() ?? 255) < 30, solid = (centre.first ?? 0) > 230
                if clear && solid { good += 1 }
                lines.append("\(name)\t\(v)\t\(clear ? 1 : 0)\t\(solid ? 1 : 0)\t| \(clear ? "" : "background left in the corners ") \(solid ? "" : "holes in the person")")
            }
        }
        lines.insert(String(format: "SCORE cutout n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: PDF tools on real-world PDFs (PDF.js test corpus: odd fonts, scans, forms, rotations)

    func testPDFToolsKeepEveryPageAndDoWhatTheySay() async throws {
        guard let root else { throw XCTSkip("runs in the QA lab") }
        let dir = root.appendingPathComponent("pdfs")
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.lowercased().hasSuffix(".pdf") }.sorted()
        guard !files.isEmpty else { throw XCTSkip("PDF corpus not downloaded") }
        var lines = ["PDF TOOLS\tfile\tpages\treorder\tlock\tshrink\tsearchable\t| problem"]
        var good = 0.0, n = 0.0
        var ocrDone = 0
        func text(_ d: Data?, _ i: Int) -> String { d.flatMap { PDFDocument(data: $0)?.page(at: i)?.string } ?? "" }
        for f in files {
            guard let data = try? Data(contentsOf: dir.appendingPathComponent(f)), let doc = PDFDocument(data: data), doc.pageCount > 0, !doc.isLocked else { continue }
            let pages = doc.pageCount
            var fails: [String] = []
            // Organize Pages: reversed, every page kept, text still there and in the new order.
            var items = PDFPages.items(pageCount: pages); items.reverse()
            let re = PDFPages.build(data, items: items)
            let reOK = re.flatMap { PDFDocument(data: $0)?.pageCount } == pages && text(re, 0) == text(data, pages - 1)
            if !reOK { fails.append("reorder lost or mixed pages") }
            // Protect: asks for the password, wrong one refused, right one gives every page back.
            let locked = PDFSecure.protect(data, password: "Tenzy-123")
            let lockOK = locked.map { PDFSecure.isLocked($0) && PDFSecure.unlock($0, password: "nope") == nil
                && PDFSecure.unlock($0, password: "Tenzy-123").flatMap { PDFDocument(data: $0)?.pageCount } == pages } ?? false
            if !lockOK { fails.append("password lock doesn't hold") }
            // Fit It: half the size (at least 100 KB), still every page.
            let target = max(100_000, data.count / 2)
            let small = data.count > 150_000 ? await SizeTarget.pdf(data, targetBytes: target) : data
            let shrinkOK = small.map { $0.count <= max(target, data.count <= 150_000 ? data.count : target) && PDFDocument(data: $0)?.pageCount == pages } ?? false
            if !shrinkOK { fails.append(small == nil ? "couldn't shrink" : "shrunk file over the limit or lost pages") }
            // Searchable: a PDF with no text layer gets one (first few only — OCR is slow).
            var searchText = "has text"
            if !PDFSearchable.hasText(data), ocrDone < 6, pages <= 6 {
                ocrDone += 1
                let made = await PDFSearchable.make(data)
                let ok = made.map { PDFSearchable.hasText($0.data) && PDFDocument(data: $0.data)?.pageCount == pages } ?? false
                searchText = ok ? "made" : "failed"
                if !ok { fails.append("no text layer added") }
            }
            n += 1; if fails.isEmpty { good += 1 }
            lines.append("\(f)\t\(pages)\t\(reOK ? 1 : 0)\t\(lockOK ? 1 : 0)\t\(shrinkOK ? 1 : 0)\t\(searchText)\t| \(fails.joined(separator: "; "))")
        }
        lines.insert(String(format: "SCORE pdf-tools n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: audio tools on real recordings (LibriSpeech read-aloud speech)

    static func seconds(_ url: URL) async -> Double? {
        guard let d = try? await AVURLAsset(url: url).load(.duration), d.isNumeric else { return nil }
        return d.seconds
    }

    func testAudioToolsGiveTheRightLengthAndFormat() async throws {
        guard let root else { throw XCTSkip("runs in the QA lab") }
        let dir = root.appendingPathComponent("speech")
        let clips = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".wav") }.sorted()
            .map { dir.appendingPathComponent($0) }
        guard clips.count >= 2 else { throw XCTSkip("speech recordings not downloaded") }
        var lines = ["AUDIO TOOLS\tclip\tlength\tconvert\tcompress\tringtone\ttrim+fade\t2× speed\t| problem"]
        var good = 0.0, n = 0.0
        func near(_ a: Double?, _ b: Double, _ tol: Double) -> Bool { a.map { abs($0 - b) <= tol } ?? false }
        for (i, clip) in clips.prefix(10).enumerated() {
            guard let len = await Self.seconds(clip), len > 3 else { continue }
            var fails: [String] = []
            var conv = true
            for f in [AudioConvert.Format.m4a, .aiff] {
                if case .success(let u) = await AudioConvert.convert(clip, to: f) {
                    if !near(await Self.seconds(u), len, 0.15) { conv = false; fails.append("\(f.rawValue) length changed") }
                } else { conv = false; fails.append("\(f.rawValue) failed") }
            }
            let size = (try? clip.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var comp = false
            if case .success(let r) = await AudioConvert.compress(clip, level: .smallest) {
                let s2 = (try? r.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? .max
                let got = await Self.seconds(r.url)
                comp = s2 < size / 4 && near(got, len, 0.15)
                if !comp { fails.append("compress: \(s2 / 1000) KB from \(size / 1000) KB") }
            } else { fails.append("compress failed") }
            var ring = false
            if case .success(let u) = await AudioConvert.ringtone(clip, start: 1, length: 2.5, fade: 0.3) {
                ring = near(await Self.seconds(u), 2.5, 0.2) && u.pathExtension.lowercased() == "m4r"
                if !ring { fails.append("ringtone length or type wrong") }
            } else { fails.append("ringtone failed") }
            var trim = false
            var o = AudioEdit.Options(); o.start = 1; o.end = 3; o.fadeIn = 0.3; o.fadeOut = 0.3
            if case .success(let u) = await AudioEdit.edit(clip, options: o) {
                let got = await Self.seconds(u) ?? -1
                trim = near(got, 2, 0.2)
                if !trim { fails.append("trim gave \(String(format: "%.2f", got)) s, wanted 2") }
            } else { fails.append("trim failed") }
            var fast = false
            if case .success(let u) = await AudioMix.speed(clip, rate: 2) {
                let got = await Self.seconds(u) ?? -1
                fast = near(got, len / 2, max(0.25, len * 0.06))
                if !fast { fails.append("2× speed gave \(String(format: "%.2f", got)) s from \(String(format: "%.2f", len))") }
            } else { fails.append("speed failed") }
            n += 1; if fails.isEmpty { good += 1 }
            lines.append("\(i)\t\(String(format: "%.1f", len))\t\(conv ? 1 : 0)\t\(comp ? 1 : 0)\t\(ring ? 1 : 0)\t\(trim ? 1 : 0)\t\(fast ? 1 : 0)\t| \(fails.joined(separator: "; "))")
        }
        // Join: two clips end to end make one clip as long as both.
        if clips.count >= 2, let a = await Self.seconds(clips[0]), let b = await Self.seconds(clips[1]) {
            n += 1
            if case .success(let u) = await AudioMix.merge([clips[0], clips[1]]), near(await Self.seconds(u), a + b, 0.3) { good += 1; lines.append("join\t\(String(format: "%.1f", a + b))\t\t\t\t\t\t| ") }
            else { lines.append("join\t\(String(format: "%.1f", a + b))\t\t\t\t\t\t| joined length wrong or failed") }
        }
        lines.insert(String(format: "SCORE audio-tools n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: whole flows on real photos (the same chains the Builder, Guide and Share sheet run)

    func testPhotoFlowsDeliverWhatTheySay() async throws {
        let photos = try privatePhotos()
        var lines = ["PHOTO FLOWS\tflow\tphoto\t| result"]
        var good = 0.0, n = 0.0
        func chain(_ id: String) -> Chain? { ChainTemplates.all.first { $0.id == id } }
        func data(_ p: ChainPayload) -> Data? {
            switch p { case .file(let d, _): return d; case .image(let i): return i.jpegData(compressionQuality: 0.92); default: return nil }
        }
        for (name, img) in photos {
            // Under 2 MB: really under, still a photo.
            if let c = chain("photo-under-2mb") {
                n += 1
                let r = await ChainRunner.run(c, input: .image(img))
                if case .success(let p) = r, let d = data(p), d.count <= 2_000_000, UIImage(data: d) != nil { good += 1; lines.append("under 2 MB\t\(name)\t| \(d.count / 1000) KB") }
                else { lines.append("under 2 MB\t\(name)\t| FAILED") }
            }
            // Safe to share: no location or camera data left.
            if let c = chain("safe-to-share") {
                n += 1
                let r = await ChainRunner.run(c, input: .image(img))
                if case .success(let p) = r, let d = data(p), !Scrubber.metadata(in: d).hasGPS,
                   let props = CGImageSourceCreateWithData(d as CFData, nil).flatMap({ CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [String: Any] }),
                   props[kCGImagePropertyGPSDictionary as String] == nil { good += 1; lines.append("safe to share\t\(name)\t| no location") }
                else { lines.append("safe to share\t\(name)\t| FAILED: location data left or no file") }
            }
        }
        // Hide faces: every face found before is gone after.
        for (name, face) in try privatePhotos("face-") {
            for (v, img) in [("as taken", face), ("farther away", Self.farther(face))] {
                guard let c = chain("share-shield") else { continue }
                n += 1
                let before = Scrubber.faces(in: img).count
                let r = await ChainRunner.run(c, input: .image(img))
                if case .success(let p) = r, let d = data(p), let out = UIImage(data: d) {
                    let after = Scrubber.faces(in: out).count
                    if before > 0 && after == 0 && d.count <= 2_000_000 { good += 1 }
                    lines.append("hide faces\t\(name) \(v)\t| \(before) face(s) before, \(after) after, \(d.count / 1000) KB")
                } else { lines.append("hide faces\t\(name) \(v)\t| FAILED") }
            }
        }
        lines.insert(String(format: "SCORE photo-flows n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: Studio profile picture on a real face

    func testProfilePictureCentresTheFace() throws {
        let faces = try privatePhotos("face-")
        var lines = ["PROFILE PICTURE\tphoto\tvariant\tface centre x\thead share\t| problem"]
        var good = 0.0, n = 0.0
        for (name, face) in faces {
            for (v, img) in [("as taken", face), ("farther away", Self.farther(face)), ("tilted", ToughPhotoTests.trouble(face, .tilt))] {
                n += 1
                guard let out = ImageStudio.profile(img), let cg = out.cgImage, let f = PassportPhoto.analyze(cg) else {
                    lines.append("\(name)\t\(v)\t—\t—\t| no picture or no face in it"); continue
                }
                let cx = f.centreX / CGFloat(cg.width), share = (f.chin.y - f.crown.y) / CGFloat(cg.height)
                var fails: [String] = []
                if cg.width != 1080 || cg.height != 1080 { fails.append("not 1080 square") }
                if abs(cx - 0.5) > 0.06 { fails.append("face off centre") }
                if share < 0.4 || share > 0.72 { fails.append("head \(Int(share * 100))% of the height") }
                if f.crown.y < CGFloat(cg.height) * 0.04 { fails.append("top of the head cut off") }
                if fails.isEmpty { good += 1 }
                lines.append("\(name)\t\(v)\t\(String(format: "%.2f", cx))\t\(String(format: "%.2f", share))\t| \(fails.joined(separator: "; "))")
            }
        }
        lines.insert(String(format: "SCORE profile-picture n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }

    // MARK: what is this? — written things

    /// Every private photo through "What is this?": a written thing must be named as the kind it is (a schedule
    /// board, a receipt, a menu, a poster…), and a schedule must come back with its people by day. A face is not paper.
    func testIdentifyNamesWrittenThingsByKind() async throws {
        let photos = try privatePhotos()
        func expected(_ n: String) -> [Paper.Kind?]? {
            if n.hasPrefix("face-") { return [nil] }
            if n.hasPrefix("receipt-") { return [.receipt] }
            if n.hasPrefix("menu-") { return [.menu] }
            if n.hasPrefix("poster-") { return [.poster, .page] }
            if n.contains("people-week") || n.contains("schedule") { return [.schedule] }
            if n.contains("calendar") { return [.calendar] }
            if n.contains("todo") { return [.lists] }
            return nil
        }
        var lines = ["IDENTIFY\tphoto\tgot\tgist\t| ok"]
        var good = 0.0, n = 0.0
        for (name, img) in photos {
            guard let want = expected(name) else { continue }
            n += 1
            let o = await Identifier.identify(img)
            let got = o.paper?.kind
            var ok = want.contains(got)
            if got == .schedule, name.contains("schedule") {
                // The whiteboard rota has 20 names down the side: most of them must come back.
                let people = Set(Understand.parse(DocEngine.recognize(img.normalizedUp()), now: Date()).people.map(\.person)).count
                if people < 12 { ok = false }
                lines.append("\(name)\tpeople read: \(people)")
            }
            if ok { good += 1 }
            lines.append("\(name)\t\(got?.rawValue ?? "not paper (\(o.guesses.first?.label ?? "-"))")\t\(o.paper?.gist ?? "")\t| \(ok ? "ok" : "WRONG, wanted \(want.map { $0?.rawValue ?? "not paper" })")")
        }
        lines.insert(String(format: "SCORE identify-written n=%.0f %.3f", n, good / max(1, n)), at: 0)
        report(lines)
    }
}

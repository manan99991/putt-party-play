import XCTest
import SQLite3
import Compression
@testable import HandyTools

/// File Opener reads each family of file into something you can go through — made here from real bytes, the way
/// those files are built, and checked for the content coming back (not just "it opened").
final class FileReadersTests: XCTestCase {
    private func file(_ name: String, _ data: Data) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fr-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent(name); try? data.write(to: u); return u
    }
    private func zip(_ items: [(String, String)]) -> Data {
        guard case .success(let d) = ZipWriter.zip(items.map { ZipWriter.Item(name: $0.0, data: Data($0.1.utf8)) }, keepPaths: true) else { XCTFail("zip"); return Data() }
        return d
    }

    func testTablesInEverySeparator() {
        for (ext, body) in [("tsv", "Name\tCity\nAsha\tPune\n"), ("psv", "Name|City\nAsha|Pune\n"), ("ssv", "Name;City\nAsha;Pune\n"), ("csv", "Name;City\nAsha;Pune\n"), ("csv", "Name,City\n\"Shah, M\",\"Plainfield\"\n")] {
            guard case .table(let rows, _) = FileReaders.read(file("t.\(ext)", Data(body.utf8))) else { return XCTFail("\(ext) not a table") }
            XCTAssertEqual(rows.first, ["Name", "City"], ext)
            XCTAssertEqual(rows.count, 2, ext)
        }
    }

    func testAnEPUBBookReadsByChapter() {
        let d = zip([("mimetype", "application/epub+zip"),
                     ("META-INF/container.xml", #"<container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>"#),
                     ("OEBPS/content.opf", #"<package><metadata><dc:title>Don't Give Up</dc:title><dc:creator>J. P.</dc:creator></metadata><manifest><item id="c1" href="one.xhtml"/><item id="c2" href="two.xhtml"/></manifest><spine><itemref idref="c1"/><itemref idref="c2"/></spine></package>"#),
                     ("OEBPS/one.xhtml", "<html><head></head><body><h1>Morning</h1><p>It began.</p></body></html>"),
                     ("OEBPS/two.xhtml", "<html><head></head><body><h1>Night</h1><p>It ended.</p></body></html>")])
        guard case .book(let b) = FileReaders.read(file("story.epub", d)) else { return XCTFail("not a book") }
        XCTAssertEqual(b.title, "Don't Give Up"); XCTAssertEqual(b.author, "J. P.")
        XCTAssertEqual(b.chapters.map(\.title), ["Morning", "Night"])
        XCTAssertTrue(b.chapters[1].html.contains("It ended."))
    }

    func testAMobipocketBookIsDecompressedAndAKindleLockedOneSaysSo() {
        // PalmDOC: literal "Hello " then a back-reference copying "Hello " again.
        let text = Array("Hello ".utf8) + [0x80 | 0x00, (6 << 3) | 3]          // distance 6, length 6
        XCTAssertEqual(String(decoding: FileReaders.palmDOC(text), as: UTF8.self), "Hello Hello ")
        func book(drm: Bool) -> Data {
            var b = [UInt8](repeating: 0, count: 78)
            for (i, c) in "Test".utf8.enumerated() { b[i] = c }
            for (i, c) in "BOOKMOBI".utf8.enumerated() { b[60 + i] = c }
            b[76] = 0; b[77] = 2
            let rec0Off = 78 + 16 + 2, rec1Off = rec0Off + 16
            func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)] }
            b += be32(rec0Off) + [0, 0, 0, 0] + be32(rec1Off) + [0, 0, 0, 1] + [0, 0]
            var r0 = [UInt8](repeating: 0, count: 16); r0[1] = 1; r0[9] = 1; if drm { r0[13] = 2 }  // compression 1 = none, 1 text record
            return Data(b + r0 + Array("<p>Chapter one text here, long enough.</p>".utf8))
        }
        guard case .book(let b) = FileReaders.read(file("t.mobi", book(drm: false))) else { return XCTFail("not read") }
        XCTAssertTrue(b.chapters.first?.html.contains("Chapter one text") ?? false)
        guard case .info(_, let detail, _) = FileReaders.read(file("t.azw3", book(drm: true))) else { return XCTFail("DRM not explained") }
        XCTAssertTrue(detail.contains("Kindle"))
    }

    func testAComicPagesInOrder() {
        let png = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { c in UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 4, height: 4)) }
        guard case .success(let d) = ZipWriter.zip([ZipWriter.Item(name: "p10.png", data: png), ZipWriter.Item(name: "p2.png", data: png), ZipWriter.Item(name: "p1.png", data: png)], keepPaths: true) else { return XCTFail() }
        guard case .comic(let pages) = FileReaders.read(file("issue.cbz", d)) else { return XCTFail("not a comic") }
        XCTAssertEqual(pages.count, 3)
        // A .cbr that's really a ZIP still opens.
        guard case .comic = FileReaders.read(file("issue.cbr", d)) else { return XCTFail("zip-in-cbr not opened") }
    }

    func testAnEmailWithAnAttachment() {
        let eml = """
        From: =?UTF-8?B?TWFuYW4gU2hhaA==?= <m@example.com>
        To: you@example.com
        Subject: Your receipt
        Content-Type: multipart/mixed; boundary="XX"

        --XX
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: quoted-printable

        Thanks =E2=80=94 see attached.
        --XX
        Content-Type: application/pdf; name="receipt.pdf"
        Content-Disposition: attachment; filename="receipt.pdf"
        Content-Transfer-Encoding: base64

        JVBERi0xLjQK
        --XX--
        """
        guard case .email(let e) = FileReaders.read(file("m.eml", Data(eml.utf8))) else { return XCTFail("not an email") }
        XCTAssertEqual(e.from, "Manan Shah <m@example.com>")
        XCTAssertEqual(e.subject, "Your receipt")
        XCTAssertTrue(e.text.contains("Thanks — see attached."))
        XCTAssertEqual(e.attachments.first?.name, "receipt.pdf")
        XCTAssertEqual(e.attachments.first?.data, Data("%PDF-1.4\n".utf8))
    }

    func testADatabaseShowsItsTables() {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).sqlite")
        var db: OpaquePointer?
        sqlite3_open(u.path, &db)
        sqlite3_exec(db, "CREATE TABLE people(name TEXT, city TEXT); INSERT INTO people VALUES('Asha','Pune');", nil, nil, nil)
        sqlite3_close(db)
        guard case .database(let t) = FileReaders.read(u) else { return XCTFail("not a database") }
        XCTAssertEqual(t.first?.table, "people")
        XCTAssertEqual(t.first?.rows, [["name", "city"], ["Asha", "Pune"]])
    }

    func testATarGzListsAndOpensWhatsInside() {
        var tar = [UInt8](repeating: 0, count: 512)
        for (i, c) in "notes/hello.txt".utf8.enumerated() { tar[i] = c }
        for (i, c) in "00000000005\0".utf8.enumerated() { tar[124 + i] = c }
        tar[156] = UInt8(ascii: "0")
        tar += Array("hello".utf8) + [UInt8](repeating: 0, count: 507) + [UInt8](repeating: 0, count: 1024)
        // gzip = header + raw deflate (Compression's ZLIB is raw deflate) + crc + size
        let raw = Data(tar)
        var dst = [UInt8](repeating: 0, count: raw.count + 1024)
        let n = raw.withUnsafeBytes { s in compression_encode_buffer(&dst, dst.count, s.bindMemory(to: UInt8.self).baseAddress!, raw.count, nil, COMPRESSION_ZLIB) }
        let size = raw.count
        let gz = Data([0x1F, 0x8B, 8, 0, 0, 0, 0, 0, 0, 3] + dst[0..<n] + [0, 0, 0, 0, UInt8(size & 255), UInt8(size >> 8 & 255), UInt8(size >> 16 & 255), 0])
        guard case .archive(let entries, let kind) = FileReaders.read(file("notes.tar.gz", gz)) else { return XCTFail("not an archive") }
        XCTAssertEqual(kind, "TAR (GZip)")
        XCTAssertEqual(entries.map(\.name), ["notes/hello.txt"])
        XCTAssertEqual(entries.first?.data(), Data("hello".utf8))
    }

    func testOddPicturesCodeJSONAndOfficeVariants() {
        guard case .image(let img) = FileReaders.read(file("dot.ppm", Data("P3\n2 1\n255\n255 0 0  0 0 255\n".utf8))) else { return XCTFail("ppm") }
        XCTAssertEqual(img.size, CGSize(width: 2, height: 1))
        guard case .text(let t, _) = FileReaders.read(file("data.json", Data(#"{"b":1,"a":[1,2]}"#.utf8))) else { return XCTFail("json") }
        XCTAssertTrue(t.contains("\"a\" : ["))
        guard case .text = FileReaders.read(file("build.gradle", Data("plugins { id 'app' }".utf8))) else { return XCTFail("code") }
        guard case .quickLook(let q) = FileReaders.read(file("budget.xlsm", Data("PK".utf8))) else { return XCTFail("xlsm") }
        XCTAssertEqual(q.pathExtension, "xlsx")
        guard case .info(let kind, _, _) = FileReaders.read(file("setup.bin", Data([0x4D, 0x5A, 0x90, 0, 3, 0]))) else { return XCTFail("exe") }
        XCTAssertTrue(kind.contains("Windows program"))
    }
}

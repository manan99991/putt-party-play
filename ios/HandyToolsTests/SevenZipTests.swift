import XCTest
@testable import HandyTools

/// 7-Zip and BZip2 open in File Opener (tier 2). Made-up files: a .7z (LZMA2, two files in a folder) and a .bz2 log.
final class SevenZipTests: XCTestCase {
    private let sevenZip = Data(base64Encoded: "N3q8ryccAAQyOFO/uQEAAAAAAAAWAAAAAAAAALynYq7gF/EBO10AKBhIZtw2K9ezxoOuST5SRNFPhRI5Ltvz0JGGxetPUUlgLx3yjocQZ1/k9i+Tlui+hie2pd+oQAHrHDAoSbmjj8d+KR0YkzDIV08/HuiDxJxcoQ9ON0yEf4UfLVpT6EwnlingksloWLyiI2OjtR22P6t2oKHkxHZrA/BQYQbIyyN2nwhDEGkHmdAxt5Nbc6ChepX18UIc3iR++229l8sL5jifSRfJDEuJ5O1F4/dQSs0AvOdmpYLfFG48uQQdA+cH2L0VpWEsO2AGlmWAClu2a4uE5BSOlP2GM7Rw0vPCQpB5yJj/iF5P2fIWqIhI65Uk7o0hdspVDM3Gydv8Yv4W3HGYXq9TL2j7R41iUQcIdje2ye2P43C5+xPht0lSqijDt9Gq35WcRTozSp0LxQhtW81LS9YukPk8dWAAAOAAjABuXQAAgTMHrg/VOU3l1yTT/rNwFrGGiQ5q3/qjIYdezuLMj5EwJ9ObBzgX1a2uBmfJ7y6jDIhP0/6D1VvJCaXJXw0C3w99y9lFZ5Li1VsLRA2/3gLRkvZK0ctpuy2+3WDl9vZRSBAsNfA1Eyet8zIAAAAXBoFDAQl2AAcLAQABISEBGAyAjQAA")!
    private let bz2 = Data(base64Encoded: "QlpoOTFBWSZTWfhqlKIAAA7ZgAAQQAJxECYAHSAgAFRABBgEqYgPUGkq5huaHEFRDDQIRCIHKlgc55u7iZt9zMEcL0XckU4UJD4apSiA")!

    private func write(_ d: Data, _ name: String) throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(name); try d.write(to: u); return u
    }

    func testSevenZipListsAndOpensEachFile() throws {
        guard case .archive(let entries, let kind) = FileReaders.read(try write(sevenZip, "trip.7z")) else { return XCTFail("a .7z should open as an archive") }
        XCTAssertEqual(kind, "7-Zip")
        XCTAssertEqual(Set(entries.map(\.name)), ["trip/list.txt", "trip/plan.txt"])
        let list = try XCTUnwrap(entries.first { $0.name == "trip/list.txt" }?.data())
        let text = String(decoding: list, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("Packing list:"), text)
        XCTAssertTrue(text.contains("- item 199: tent pegs and rope"), "the whole file, not a part")
    }

    func testBZip2LogOpens() throws {
        guard case .archive(let entries, let kind) = FileReaders.read(try write(bz2, "server.log.bz2")) else { return XCTFail("a .bz2 should open") }
        XCTAssertEqual(kind, "BZip2")
        let d = try XCTUnwrap(entries.first?.data())
        XCTAssertTrue(String(decoding: d, as: UTF8.self).contains("server started"))
    }
}

import XCTest
@testable import HandyTools

/// Each ready-made "photo of paper" tool, run end to end on made-up paper of its own kind (a card, a poster, a shelf,
/// a whiteboard, a Wi-Fi sign, a recent receipt), with the result read back — the same papers the UI tests and
/// screenshots now use, so the finished screens show the real job working.
final class SampleJobTests: XCTestCase {
    private func run(_ id: String, _ job: Block) async throws -> ChainPayload {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == id })
        let img = SampleAssets.paper(for: job)
        let d = try XCTUnwrap(img.jpegData(compressionQuality: 0.9))
        switch await ChainRunner.run(c, input: .file(d, ext: "jpg")) {
        case .success(let p): return p
        case .failure(let f): XCTFail("\(id): \(f)"); throw XCTSkip("no result")
        }
    }
    private func text(_ p: ChainPayload) -> String {
        switch p {
        case .text(let t): return t
        case .file(let d, _): return String(data: d, encoding: .utf8) ?? ""
        default: return ""
        }
    }

    func testBusinessCardBecomesAContactWithThePhoneAndEmail() async throws {
        let vcf = text(try await run("card-to-contact", .businessCard))
        XCTAssertTrue(vcf.contains("Maya"), vcf)
        XCTAssertTrue(vcf.contains("555") && vcf.contains("0199"), vcf)
        XCTAssertTrue(vcf.lowercased().contains("maya@northwind.example"), vcf)
    }

    func testPosterBecomesAnEventOnItsDay() async throws {
        let ics = text(try await run("poster-to-event", .calendarEvent))
        XCTAssertTrue(ics.uppercased().contains("BOOK SWAP"), ics)
        let want = Calendar.current.date(byAdding: .day, value: 12, to: Date())!
        let raw = try XCTUnwrap(ics.components(separatedBy: "\n").first { $0.hasPrefix("DTSTART:") }?.dropFirst(8)
            .trimmingCharacters(in: .whitespacesAndNewlines), ics)
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(identifier: "UTC")
        let start = try XCTUnwrap(f.date(from: raw), raw)
        XCTAssertTrue(Calendar.current.isDate(start, inSameDayAs: want), "event on \(start), poster says \(want)")
        XCTAssertEqual(Calendar.current.component(.hour, from: start), 18, "6:30 PM on the poster")
    }

    func testShelfFindsTheCheaperPerKilo() async throws {
        let out = text(try await run("shelf-best-deal", .priceCompare))
        XCTAssertTrue(out.contains("B") || out.contains("1 kg"), "Brand B ($3.99/kg) should win: \(out)")
    }

    func testWhiteboardBecomesTasksWithWho() async throws {
        let out = text(try await run("whiteboard-to-tasks", .actionItems))
        XCTAssertTrue(out.contains("budget"), out)
        XCTAssertTrue(out.contains("venue"), out)
    }

    func testWifiSignBecomesAJoinCode() async throws {
        let p = try await run("wifi-sign", .wifiQr)
        if case .image = p {} else { XCTFail("no join code picture") }
    }

    func testRecentReceiptGetsAReturnByReminder() async throws {
        let ics = text(try await run("return-by", .returnBy))
        XCTAssertTrue(ics.contains("BEGIN:VEVENT"), ics)
    }
}

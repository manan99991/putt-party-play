import XCTest
@testable import HandyTools

/// Outlook files open as ordinary email (File Opener tier 2). The two files below are made up and tiny: a saved
/// Outlook message (.msg, a compound file built to the spec and checked with olefile) and a winmail.dat (TNEF).
final class OfficeMailTests: XCTestCase {
    private let msg = Data(base64Encoded: "0M8R4KGxGuEAAAAAAAAAAAAAAAAAAAAAPgADAP7/CQAGAAAAAAAAAAAAAAABAAAAAQAAAAAAAAAAEAAABAAAAAEAAAD+////AAAAAAAAAAD////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9////AgAAAAMAAAD+/////v///wYAAAD+/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////1IAbwBvAHQAIABFAG4AdAByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWAAUB//////////8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQAAAEACAAAAAAAAXwBfAHMAdQBiAHMAdABnADEALgAwAF8AMAAwADMANwAwADAAMQBGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACoAAgH/////AgAAAP////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAAAAAAAAABfAF8AcwB1AGIAcwB0AGcAMQAuADAAXwAxADAAMAAwADAAMAAxAEYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKgACAf////8DAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAABiAAAAAAAAAF8AXwBzAHUAYgBzAHQAZwAxAC4AMABfADAAQwAxAEEAMAAwADEARgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqAAIB/////wQAAAD/////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAABQAAAAAAAAAXwBfAHMAdQBiAHMAdABnADEALgAwAF8ANQBEADAAMQAwADAAMQBGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACoAAgH/////BQAAAP////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAALAAAAAAAAABfAF8AcwB1AGIAcwB0AGcAMQAuADAAXwAwAEUAMAA0ADAAMAAxAEYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKgACAf////8GAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUAAAAcAAAAAAAAAF8AXwBwAHIAbwBwAGUAcgB0AGkAZQBzAF8AdgBlAHIAcwBpAG8AbgAxAC4AMAAAAAAAAAAAAAAAAAAAAAAAAAAwAAIB/////wcAAAD/////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgAAADAAAAAAAAAAXwBfAGEAdAB0AGEAYwBoAF8AdgBlAHIAcwBpAG8AbgAxAC4AMABfACMAMAAwADAAMAAwADAAMAAwAAAAAAAAADwAAQH//////////wgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABfAF8AcwB1AGIAcwB0AGcAMQAuADAAXwAzADcAMAA3ADAAMAAxAEYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKgACAf////8JAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcAAAAQAAAAAAAAAF8AXwBzAHUAYgBzAHQAZwAxAC4AMABfADMANwAwADEAMAAxADAAMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqAAIB////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAABkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP7///8CAAAA/v////7////+/////v////7////+/////v//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////UQB1AGEAcgB0AGUAcgBsAHkAIABwAGwAYQBuACAAFCAgAGQAcgBhAGYAdAAAAAAAAAAAAAAAAAAAAAAAAAAAAEgAaQAgAHQAZQBhAG0ALAAKAFQAaABlACAAZAByAGEAZgB0ACAAcABsAGEAbgAgAGkAcwAgAGEAdAB0AGEAYwBoAGUAZAAuAAoAVABoAGEAbgBrAHMALAAgAE0AYQB5AGEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATQBhAHkAYQAgAFAAYQB0AGUAbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAG0AYQB5AGEAQABuAG8AcgB0AGgAdwBpAG4AZAAuAGUAeABhAG0AcABsAGUAAAAAAAAAAAAAAAAAAAAAAAAAAABUAGUAYQBtACAATgBvAHIAdABoAHcAaQBuAGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAADkABgAAAADYRjjKLtsBAAAAAAAAAAAAAAAAAAAAAHAAbABhAG4ALgB0AHgAdAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABTdGVwIDE6IGFncmVlIHRoZSBnb2Fscy4KAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==")!
    private let tnef = Data(base64Encoded: "eJ8+IjQSAQSAAQAPAAAAUXVhcnRlcmx5IHBsYW4AlAUCApAGAA4AAAAAAAAAAAAAAAAAAAAAAAAAAhCAAQANAAAAUExBTi1GfjEuVFhUAHsDAg+ABgAZAAAAU3RlcCAxOiBhZ3JlZSB0aGUgZ29hbHMuChoIAgWQBgAwAAAAAQAAAB8ABzcBAAAAHgAAAHAAbABhAG4ALQBmAGkAbgBhAGwALgB0AHgAdAAAAAAA7QU=")!

    func testOutlookMessageReadsLikeAnEmail() throws {
        let e = try XCTUnwrap(OfficeMail.msg(msg))
        XCTAssertEqual(e.subject, "Quarterly plan — draft")
        XCTAssertEqual(e.from, "Maya Patel <maya@northwind.example>")
        XCTAssertEqual(e.to, "Team Northwind")
        XCTAssertTrue(e.text.contains("The draft plan is attached."), e.text)
        XCTAssertFalse(e.date.isEmpty, "the sent time wasn't read")
        XCTAssertEqual(e.attachments.count, 1)
        XCTAssertEqual(e.attachments.first?.name, "plan.txt")
        XCTAssertEqual(e.attachments.first.map { String(decoding: $0.data, as: UTF8.self) }, "Step 1: agree the goals.\n")
    }

    func testWinmailDatGivesBackTheRealAttachment() throws {
        let e = try XCTUnwrap(OfficeMail.tnef(tnef))
        XCTAssertEqual(e.subject, "Quarterly plan")
        XCTAssertEqual(e.attachments.map(\.name), ["plan-final.txt"], "the long name from Outlook's properties, not the 8.3 one")
        XCTAssertEqual(e.attachments.first.map { String(decoding: $0.data, as: UTF8.self) }, "Step 1: agree the goals.\n")
    }

    func testNotAnOutlookFileIsNotMistakenForOne() {
        XCTAssertNil(OfficeMail.msg(Data("hello".utf8)))
        XCTAssertNil(OfficeMail.tnef(Data("hello world".utf8)))
    }

    func testTheFileOpenerRoutesBothToTheEmailView() throws {
        let dir = FileManager.default.temporaryDirectory
        let m = dir.appendingPathComponent("Quarterly plan.msg"), w = dir.appendingPathComponent("winmail.dat")
        try msg.write(to: m); try tnef.write(to: w)
        if case .email(let e) = FileReaders.read(m) { XCTAssertEqual(e.attachments.count, 1) } else { XCTFail(".msg didn't open as email") }
        if case .email(let e) = FileReaders.read(w) { XCTAssertEqual(e.attachments.first?.name, "plan-final.txt") } else { XCTFail("winmail.dat didn't open as email") }
    }
}

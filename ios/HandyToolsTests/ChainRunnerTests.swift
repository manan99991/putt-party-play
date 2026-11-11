import XCTest
import UIKit
@testable import HandyTools

/// Builder M1: chains are validated and run by the same engines the tools use.
final class ChainRunnerTests: XCTestCase {

    func testTemplatesAreValidAndCodable() throws {
        for t in ChainTemplates.all {
            let start: ChainKind = t.steps.first?.block.takes ?? .image
            XCTAssertNil(t.problem(starting: start), t.name)
            let back = try JSONDecoder().decode(Chain.self, from: JSONEncoder().encode(t))
            XCTAssertEqual(back, t, "a chain must survive export and import unchanged")
        }
    }

    func testMismatchedStepsAreRejectedInPlainWords() {
        let c = Chain(id: "x", name: "x", steps: [ChainStep(block: .summarize)])
        XCTAssertNotNil(c.problem(starting: .image))
        XCTAssertNil(c.problem(starting: .text))
        XCTAssertNotNil(Chain(id: "e", name: "e", steps: []).problem(starting: .image))
    }

    func testRunnerRefusesInvalidChainWithoutRunning() async {
        let c = Chain(id: "x", name: "x", steps: [ChainStep(block: .summarize)])
        let r = await ChainRunner.run(c, input: .image(SampleAssets.receipt()))
        if case .failure(.invalid) = r {} else { XCTFail("expected invalid") }
    }

    func testSummarizeBlockRuns() async {
        let text = "Cats sleep a lot. Cats also hunt at night. Dogs prefer the day. Cats and dogs differ. Birds sing."
        let r = await ChainRunner.apply(ChainStep(block: .summarize, settings: ["sentences": "2"]), to: .text(text))
        guard case .success(.text(let out)) = r else { return XCTFail("no text") }
        XCTAssertFalse(out.isEmpty)
        XCTAssertLessThan(out.count, text.count)
    }

    func testReceiptBlockProducesCSV() async {
        let text = "Corner Cafe\n12/03/2025\nLatte 4.50\nMuffin 3.25\nSubtotal 7.75\nTax 0.62\nTotal 8.37\nThank you for"
        let r = await ChainRunner.apply(ChainStep(block: .pullReceipt), to: .text(text))
        guard case .success(.text(let csv)) = r else { return XCTFail("no csv") }
        XCTAssertTrue(csv.contains("Item,Amount"))
        XCTAssertTrue(csv.contains("8.37"))
    }

    func testEmptyTextStopsWithNamedBlock() async {
        let r = await ChainRunner.apply(ChainStep(block: .pullReceipt), to: .text("hello"))
        XCTAssertEqual(r.failureValue, .nothingFound(.pullReceipt))
    }

    func testShrinkAndStripGiveJPEGFiles() async {
        let img = SampleAssets.receipt()
        let a = await ChainRunner.apply(ChainStep(block: .shrinkImage, settings: ["mb": "0.2"]), to: .image(img))
        guard case .success(.file(let d, let ext)) = a else { return XCTFail("no file") }
        XCTAssertEqual(ext, "jpg"); XCTAssertLessThanOrEqual(d.count, 210_000)
        let b = await ChainRunner.apply(ChainStep(block: .stripLocation), to: .image(img))
        guard case .success(.file(let s, _)) = b else { return XCTFail("no file") }
        XCTAssertFalse(Scrubber.metadata(in: s).hasGPS)
    }

    func testFullReceiptChainOnSampleImage() async {
        let c = ChainTemplates.all.first { $0.id == "receipt-to-row" }!
        let r = await ChainRunner.run(c, input: .image(SampleAssets.receipt()))
        guard case .success(.text(let csv)) = r else { return XCTFail("chain failed: \(r)") }
        XCTAssertTrue(csv.contains("Item,Amount"))
    }
}

private extension Result {
    var failureValue: Failure? { if case .failure(let f) = self { return f }; return nil }
}

final class ChainRowTests: XCTestCase {
    func testSplitPiecesOnOneRowAreRejoined() {
        let l = [DocEngine.OCRLine(text: "13.72", box: CGRect(x: 0.7, y: 0.50, width: 0.1, height: 0.03)),
                 DocEngine.OCRLine(text: "Total", box: CGRect(x: 0.1, y: 0.505, width: 0.1, height: 0.03)),
                 DocEngine.OCRLine(text: "Tax", box: CGRect(x: 0.1, y: 0.40, width: 0.1, height: 0.03)),
                 DocEngine.OCRLine(text: "0.97", box: CGRect(x: 0.7, y: 0.40, width: 0.1, height: 0.03))]
        let out = ChainRunner.rows(l).split(separator: "\n").map(String.init)
        XCTAssertEqual(out, ["Tax  0.97", "Total  13.72"])
        XCTAssertEqual(DataGrab.receipt(out.joined(separator: "\n")).total, 13.72)
    }
}

final class ChainTemplateTests: XCTestCase {
    func testTenTemplatesAllValid() {
        XCTAssertEqual(ChainTemplates.all.count, 10)
        XCTAssertEqual(Set(ChainTemplates.all.map(\.id)).count, 10)
    }
    func testShareRoundTripAndRejectsJunk() throws {
        let t = ChainTemplates.all[0]
        let back = try XCTUnwrap(Chain.imported(from: t.shareText))
        XCTAssertEqual(back.steps, t.steps)
        XCTAssertNotEqual(back.id, t.id, "an imported tool gets its own id")
        XCTAssertNil(Chain.imported(from: "hello"))
        XCTAssertNil(Chain.imported(from: "tenzy-tool:{\"id\":\"a\",\"name\":\"b\",\"steps\":[{\"block\":\"nope\",\"settings\":{}}]}"))
    }
    func testCardAndTaskBlocks() async {
        let card = await ChainRunner.apply(ChainStep(block: .businessCard), to: .text("Jane Doe\nDesigner\nAcme Inc\njane@acme.com\n+1 312 555 0100"))
        guard case .success(.file(let d, let ext)) = card else { return XCTFail("no vcard") }
        XCTAssertEqual(ext, "vcf"); XCTAssertTrue(String(decoding: d, as: UTF8.self).contains("jane@acme.com"))
        let tasks = await ChainRunner.apply(ChainStep(block: .actionItems), to: .text("We need to book the venue. Remember to email Sam by Friday. Weather was nice."))
        guard case .success(.text(let t)) = tasks else { return XCTFail("no tasks") }
        XCTAssertTrue(t.contains("venue") || t.contains("Sam"))
    }
}

final class ContactsTransferTests: XCTestCase {
    private func c(_ id: String, _ name: String, _ n: [String] = [], _ e: [String] = []) -> ContactsTransfer.Item { .init(id: id, name: name, numbers: n, emails: e) }

    func testSamePersonAcrossAccountsIsRecognised() {
        XCTAssertTrue(ContactsTransfer.same(c("1", "Jane Doe", ["+1 (312) 555-0100"]), c("2", "jane  doe", ["312-555-0100"])))
        XCTAssertTrue(ContactsTransfer.same(c("1", "Sam", [], ["Sam@x.com"]), c("2", "Sam", [], ["sam@x.com"])))
        XCTAssertFalse(ContactsTransfer.same(c("1", "Sam", ["3125550100"]), c("2", "Sam", ["3125550199"])), "two different Sams must both be kept")
        XCTAssertFalse(ContactsTransfer.same(c("1", "Ann", ["3125550100"]), c("2", "Bob", ["3125550100"])))
    }

    func testPlanSkipsPeopleAlreadyThereAndDuplicatesInsideTheBatch() {
        let source = [c("1", "Jane", ["3125550100"]), c("2", "Raj", ["3125550111"]), c("3", "Raj", ["3125550111"])]
        let existing = [c("9", "Jane", ["312 555 0100"])]
        let p = ContactsTransfer.plan(source: source, existing: existing)
        XCTAssertEqual(p.present.map(\.id), ["1", "3"], "Jane is already there; the second Raj repeats the first")
        XCTAssertEqual(p.copy.map(\.id), ["2"])
    }
}

final class ChainPlannerTests: XCTestCase {
    func testShrinkAndStrip() throws {
        let c = try XCTUnwrap(ChainPlanner.keywordPlan("shrink a photo under 3 mb and remove its location"))
        XCTAssertEqual(c.steps.map(\.block), [.stripLocation, .shrinkImage])
        XCTAssertEqual(c.steps.last?.settings["mb"], "3")
        XCTAssertNil(c.problem(starting: .image))
    }
    func testReceiptReadsThenPulls() throws {
        let c = try XCTUnwrap(ChainPlanner.keywordPlan("turn my receipt photo into an expense row"))
        XCTAssertEqual(c.steps.map(\.block), [.readText, .pullReceipt])
    }
    func testSummarizeText() throws {
        let c = try XCTUnwrap(ChainPlanner.keywordPlan("summarize long text in 2 sentences"))
        XCTAssertEqual(c.steps.map(\.block), [.summarize])
        XCTAssertEqual(c.steps[0].settings["sentences"], "2")
    }
    func testNonsenseGivesNothing() { XCTAssertNil(ChainPlanner.keywordPlan("make me a sandwich")) }
    func testPhotoFileFeedsImageBlocks() {
        let c = Chain(id: "x", name: "x", steps: [ChainStep(block: .hideSensitive), ChainStep(block: .shrinkImage, settings: ["mb": "1"])])
        XCTAssertNil(c.problem(starting: .image))
    }
    func testHideThenShrinkRuns() async {
        let c = Chain(id: "x", name: "x", steps: [ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "1"])])
        let r = await ChainRunner.run(c, input: .image(SampleAssets.photo()))
        guard case .success(.file(let d, _)) = r else { return XCTFail("chain failed") }
        XCTAssertLessThan(d.count, 1_100_000)
    }
}

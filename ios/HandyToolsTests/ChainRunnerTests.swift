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
    func testNineteenTemplatesAllValidAndUnique() {
        XCTAssertEqual(ChainTemplates.all.count, 19)
        XCTAssertEqual(Set(ChainTemplates.all.map(\.id)).count, 19)
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

/// The text blocks added with batch mode: tidy, find details, spreadsheet. Same rules as the Android twin.
final class TextBlockTests: XCTestCase {
    func testTidyCollapsesSpacesGapsAndRepeats() {
        let raw = "\n\n  Milk   2 \nmilk 2\n\n\n\nEggs\t12  \nEggs 12\n"
        XCTAssertEqual(TextTidy.clean(raw), "Milk 2\n\nEggs 12")
    }
    func testTidyOfBlankIsEmpty() { XCTAssertEqual(TextTidy.clean("  \n \n"), "") }

    func testDetailsFindsLinksEmailsPhonesOnce() {
        let t = "Visit https://tenzy.app/help, or www.tenzy.app. Mail Priya@Studio.example or priya@studio.example. Call (312) 555-0147 or 312-555-0147."
        let d = TextTidy.details(t)
        XCTAssertEqual(d.links, ["https://tenzy.app/help", "www.tenzy.app"], "trailing punctuation is not part of a link")
        XCTAssertEqual(d.emails, ["Priya@Studio.example"], "the same address in another case counts once")
        XCTAssertEqual(d.phones.count, 2)
    }
    func testLongDigitRunIsNotAPhone() {
        XCTAssertTrue(TextTidy.details("Card 4111111111111111 expires soon").phones.isEmpty)
    }

    func testTidyBlockStopsOnBlank() async {
        let r = await ChainRunner.apply(ChainStep(block: .cleanText), to: .text("   \n  "))
        XCTAssertEqual(r.failureValue, .nothingFound(.cleanText))
    }
    func testDetailsBlockOutputsSections() async {
        let r = await ChainRunner.apply(ChainStep(block: .pullDetails), to: .text("Write to a@b.co or call 312 555 0147"))
        guard case .success(.text(let out)) = r else { return XCTFail("no text") }
        XCTAssertTrue(out.contains("Emails\na@b.co"))
        XCTAssertTrue(out.contains("Phones\n312 555 0147"))
        XCTAssertFalse(out.contains("Links"))
    }
    func testDetailsBlockNothingFound() async {
        let r = await ChainRunner.apply(ChainStep(block: .pullDetails), to: .text("no details here"))
        XCTAssertEqual(r.failureValue, .nothingFound(.pullDetails))
    }
    func testSpreadsheetBlockGivesCSVFile() async {
        let r = await ChainRunner.apply(ChainStep(block: .makeTable), to: .text("Latte  4.50\nMuffin  3.25"))
        guard case .success(.file(let d, let ext)) = r else { return XCTFail("no file") }
        XCTAssertEqual(ext, "csv")
        XCTAssertEqual(String(data: d, encoding: .utf8), "Latte,4.50\nMuffin,3.25")
    }
    func testTidyThenDetailsChainValid() async {
        let c = Chain(id: "x", name: "x", steps: [ChainStep(block: .cleanText), ChainStep(block: .pullDetails)])
        XCTAssertNil(c.problem(starting: .text))
        let r = await ChainRunner.run(c, input: .text("a@b.co\n\n\na@b.co  "))
        guard case .success(.text(let out)) = r else { return XCTFail("chain failed") }
        XCTAssertEqual(out, "Emails\na@b.co")
    }
    func testNewBlocksSurviveShareImport() throws {
        let c = Chain(id: "x", name: "Links", steps: [ChainStep(block: .cleanText), ChainStep(block: .pullDetails)])
        let back = try XCTUnwrap(Chain.imported(from: c.shareText))
        XCTAssertEqual(back.steps.map(\.block), [.cleanText, .pullDetails])
    }

    // Describe it
    func testPlannerFindsDetails() throws {
        let c = try XCTUnwrap(ChainPlanner.keywordPlan("pull all the links and phone numbers out of some text"))
        XCTAssertEqual(c.steps.map(\.block), [.pullDetails])
    }
    func testPlannerPhotoOfTableToSpreadsheet() throws {
        let c = try XCTUnwrap(ChainPlanner.keywordPlan("turn a photo of a table into a spreadsheet"))
        XCTAssertEqual(c.steps.map(\.block), [.readText, .makeTable])
    }
    func testPlannerTidyThenSummarize() throws {
        let c = try XCTUnwrap(ChainPlanner.keywordPlan("tidy up my notes then summarize in 2 sentences"))
        XCTAssertEqual(c.steps.map(\.block), [.cleanText, .summarize])
        XCTAssertEqual(c.steps[1].settings["sentences"], "2")
    }
    func testTidyUpPhotoIsNotTextTidying() {
        let c = ChainPlanner.keywordPlan("tidy up this photo and make it clearer")
        XCTAssertEqual(c?.steps.map(\.block), [.enhance])
    }
    func testTemplatesStillValidWithNewBlocks() {
        for t in ChainTemplates.all { XCTAssertNil(t.problem(starting: t.steps.first?.block.takes ?? .image), t.name) }
        XCTAssertGreaterThanOrEqual(ChainTemplates.all.count, 13)
    }

    /// A name-only "contact" (e.g. the words "New Year" from a poster) can't be sent by WhatsApp or Messages, so the block must stop with a reason.
    func testContactNeedsPhoneOrEmail() async {
        let r = await ChainRunner.apply(ChainStep(block: .businessCard), to: .text("New Year\nParty at the hall"))
        XCTAssertEqual(r.failureValue, .nothingFound(.businessCard))
    }
}

/// What the share sheet offers for a shared photo or text.
final class ShareOffersTests: XCTestCase {
    func testPhotoShareOffersOnlyToolsThatStartFromAPhoto() {
        let offers = ChainStore.offers(for: .image, mine: [], last: nil)
        XCTAssertTrue(offers.contains { $0.id == "safe-to-share" })
        XCTAssertFalse(offers.contains { $0.id == "short-summary" }, "a text tool can't start from a photo")
        for c in offers { XCTAssertNil(c.problem(starting: .image), c.name) }
    }
    func testTextShareOffersTextTools() {
        let ids = ChainStore.offers(for: .text, mine: [], last: nil).map(\.id)
        XCTAssertTrue(ids.contains("short-summary")); XCTAssertTrue(ids.contains("links-and-numbers"))
        XCTAssertFalse(ids.contains("safe-to-share"))
    }
    func testOwnToolsComeFirstAndLastUsedGoesOnTop() {
        let mine = Chain(id: "mine-1", name: "My clean send", steps: [ChainStep(block: .stripLocation), ChainStep(block: .shrinkImage, settings: ["mb": "1"])])
        XCTAssertEqual(ChainStore.offers(for: .image, mine: [mine], last: nil).first?.id, "mine-1")
        XCTAssertEqual(ChainStore.offers(for: .image, mine: [mine], last: "photo-under-2mb").first?.id, "photo-under-2mb")
        XCTAssertEqual(ChainStore.offers(for: .image, mine: [mine], last: "no-such-tool").first?.id, "mine-1")
    }
}

/// A tool's "Then" step: share, or open an email or message already filled in.
final class ChainFinishTests: XCTestCase {
    func testToolsSavedBeforeFinishExistedStillLoad() throws {
        let old = #"{"id":"a","name":"Old tool","steps":[{"block":"stripLocation","settings":{}}]}"#
        let c = try JSONDecoder().decode(Chain.self, from: Data(old.utf8))
        XCTAssertNil(c.finish)
        XCTAssertEqual(c.steps.map(\.block), [.stripLocation])
    }
    func testFinishRoundTripsAndSplitsRecipients() throws {
        var c = Chain(id: "a", name: "Clean and email", steps: [ChainStep(block: .stripLocation)])
        c.finish = ChainFinish(kind: .mail, to: "priya@studio.example, sam@studio.example ;")
        let back = try JSONDecoder().decode(Chain.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(back, c)
        XCTAssertEqual(back.finish?.recipients, ["priya@studio.example", "sam@studio.example"])
        XCTAssertEqual(back.finish?.label, "Email it to 2 people")
    }
    func testLabels() {
        XCTAssertEqual(ChainFinish(kind: .message, to: "312 555 0147").label, "Message it to 312 555 0147")
        XCTAssertEqual(ChainFinish(kind: .mail, to: " ").label, "Email it")
        XCTAssertEqual(ChainFinish().label, "Save or share")
    }
    func testSharedToolNeverCarriesRecipients() throws {
        var c = Chain(id: "a", name: "Clean and email", steps: [ChainStep(block: .stripLocation)])
        c.finish = ChainFinish(kind: .mail, to: "priya@studio.example")
        XCTAssertFalse(c.shareText.contains("priya@studio.example"))
        let back = try XCTUnwrap(Chain.imported(from: c.shareText))
        XCTAssertEqual(back.finish, ChainFinish(kind: .mail, to: ""), "the kind travels, the address does not")
    }
    func testOutboxFromTextAndFile() throws {
        XCTAssertEqual(Outbox.make(.text("hello")), Outbox(text: "hello"))
        let box = try XCTUnwrap(Outbox.make(.file(Data("a,b".utf8), ext: "csv")))
        XCTAssertNil(box.text)
        XCTAssertEqual(box.files.first?.pathExtension, "csv")
        XCTAssertEqual(Outbox.mime(box.files[0]), "text/csv")
    }
    func testUnknownFinishKindFromAnotherPhoneFallsBackToShare() throws {
        let json = #"{"id":"a","name":"From Android","steps":[{"block":"stripLocation","settings":{}}],"finish":{"kind":"whatsapp","to":""}}"#
        let c = try JSONDecoder().decode(Chain.self, from: Data(json.utf8))
        XCTAssertEqual(c.finish?.kind, .share)
    }
}

/// Scam check, link cleaning, best deal, QR, PDF and the picture questions.
final class MoreBlocksTests: XCTestCase {
    func testScamBlockNamesTheVerdictAndWhy() async {
        let msg = "URGENT: This is the IRS. Your account will be suspended within 24 hours unless you pay the balance in Apple gift cards. Do not tell anyone. Call immediately."
        let r = await ChainRunner.apply(ChainStep(block: .scamCheck), to: .text(msg))
        guard case .success(.text(let out)) = r else { return XCTFail("no report") }
        XCTAssertTrue(out.hasPrefix("Likely a scam."), out)
        XCTAssertTrue(out.contains("•"), "it must say why")
    }
    func testScamBlockOnNormalTextIsLowRisk() async {
        let r = await ChainRunner.apply(ChainStep(block: .scamCheck), to: .text("Running ten minutes late, see you at the cafe."))
        guard case .success(.text(let out)) = r else { return XCTFail("no report") }
        XCTAssertTrue(out.hasPrefix("Looks low-risk."), out)
    }
    func testCleanLinksStripsTrackingAndKeepsTheRest() {
        XCTAssertEqual(ChainText.cleanLinks(in: "https://shop.example/item?id=7&utm_source=mail&fbclid=abc"), "https://shop.example/item?id=7")
        let mixed = ChainText.cleanLinks(in: "Look: https://shop.example/item?id=7&utm_source=mail thanks")
        XCTAssertEqual(mixed, "Look: https://shop.example/item?id=7 thanks")
        XCTAssertNil(ChainText.cleanLinks(in: "no link here"))
    }
    func testBestDealRanksByUnitPrice() throws {
        let out = try XCTUnwrap(ChainText.bestDeal(in: "Oats 500 g\n$3.20\nOats 1 kg\n$5.00"))
        XCTAssertTrue(out.hasPrefix("Best deal: Oats"), out)
        XCTAssertTrue(out.components(separatedBy: "\n").first?.contains("per 100 g") == true, out)
        XCTAssertEqual(out.components(separatedBy: "\n").count, 2)
        XCTAssertNil(ChainText.bestDeal(in: "Just one thing 500 g\n$3.20"), "nothing to compare with")
    }
    func testQrBlockGivesAnImageAndRefusesEmptyText() async {
        let ok = await ChainRunner.apply(ChainStep(block: .makeQr), to: .text("https://tenzy.app"))
        guard case .success(.image(let img)) = ok else { return XCTFail("no QR") }
        XCTAssertGreaterThan(img.size.width, 100)
        let empty = await ChainRunner.apply(ChainStep(block: .makeQr), to: .text("   "))
        XCTAssertEqual(empty.failureValue, .nothingFound(.makeQr))
    }
    func testPhotoToPdfGivesAPdfFile() async {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { c in UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 200)) }
        let r = await ChainRunner.apply(ChainStep(block: .photoPdf), to: .image(img))
        guard case .success(.file(let d, let ext)) = r else { return XCTFail("no PDF") }
        XCTAssertEqual(ext, "pdf")
        XCTAssertEqual(String(decoding: d.prefix(4), as: UTF8.self), "%PDF")
    }
    func testNewBlocksChainCorrectly() {
        XCTAssertNil(Chain(id: "x", name: "x", steps: [ChainStep(block: .readText), ChainStep(block: .priceCompare)]).problem(starting: .image))
        XCTAssertNil(Chain(id: "x", name: "x", steps: [ChainStep(block: .stripLocation), ChainStep(block: .photoPdf)]).problem(starting: .image), "a saved photo can still become a PDF")
        XCTAssertNotNil(Chain(id: "x", name: "x", steps: [ChainStep(block: .photoPdf), ChainStep(block: .shrinkImage)]).problem(starting: .image), "a PDF is not a photo")
        XCTAssertNil(Chain(id: "x", name: "x", steps: [ChainStep(block: .makeQr), ChainStep(block: .convertImage)]).problem(starting: .text))
    }
    func testPlannerUnderstandsTheNewJobs() {
        XCTAssertEqual(ChainPlanner.keywordPlan("is this message a scam")?.steps.map(\.block), [.scamCheck])
        XCTAssertEqual(ChainPlanner.keywordPlan("which is the best deal in this photo of a shelf")?.steps.map(\.block), [.readText, .priceCompare])
        XCTAssertEqual(ChainPlanner.keywordPlan("turn a link into a qr code")?.steps.map(\.block), [.makeQr])
        XCTAssertEqual(ChainPlanner.keywordPlan("strip the location and make a pdf")?.steps.map(\.block), [.stripLocation, .photoPdf])
        XCTAssertEqual(ChainPlanner.keywordPlan("what plant is this")?.steps.map(\.block), [.identify])
        XCTAssertEqual(ChainPlanner.keywordPlan("describe this photo for me")?.steps.map(\.block), [.describe])
    }
}

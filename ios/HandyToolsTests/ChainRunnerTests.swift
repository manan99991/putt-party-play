import XCTest
import UIKit
import PDFKit
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
    func testTwentyFiveTemplatesAllValidAndUnique() {
        XCTAssertEqual(ChainTemplates.all.count, 25)
        XCTAssertEqual(Set(ChainTemplates.all.map(\.id)).count, 25)
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

/// The builder's step list: start from what you have, then steps grouped by what you want.
final class BlockGoalTests: XCTestCase {
    func testEveryBlockHasAKnownGoal() {
        for b in Block.allCases { XCTAssertTrue(Block.goalOrder.contains(b.goal), "\(b.rawValue) has goal \(b.goal)") }
    }
    func testPhotoStartOffersOnlyPhotoStepsGrouped() {
        let photo = Block.starting(with: .image)
        XCTAssertTrue(photo.contains(.stripLocation)); XCTAssertFalse(photo.contains(.summarize))
        let groups = Block.grouped(photo)
        XCTAssertEqual(groups.first?.goal, "Paperwork")
        XCTAssertEqual(groups.first?.blocks, [.photoPdf, .stamp])
        XCTAssertEqual(groups.flatMap(\.blocks).count, photo.count, "no step is lost or shown twice")
        XCTAssertFalse(groups.contains { $0.goal == "Understand it" }, "text-only goals stay out of a photo's list")
    }
    func testTextStartOffersOnlyTextSteps() {
        let text = Block.starting(with: .text)
        XCTAssertTrue(text.contains(.scamCheck)); XCTAssertFalse(text.contains(.shrinkImage))
        XCTAssertEqual(Block.grouped(text).map(\.goal), ["Understand it", "Clean it up", "Turn it into something", "Money"])
    }
}

/// Watermark, exact pixel size and the small size limits that upload forms ask for.
final class PortalBlocksTests: XCTestCase {
    private func photo(_ w: CGFloat, _ h: CGFloat) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f).image { c in UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: w, height: h)) }
    }
    func testPixelsParsesCommonSpellingsAndRejectsNonsense() {
        XCTAssertEqual(ChainImage.pixels("413x531"), CGSize(width: 413, height: 531))
        XCTAssertEqual(ChainImage.pixels("600 × 600"), CGSize(width: 600, height: 600))
        XCTAssertNil(ChainImage.pixels("big")); XCTAssertNil(ChainImage.pixels("0x100")); XCTAssertNil(ChainImage.pixels("99999x10"))
    }
    func testExactSizeBlockGivesExactlyThatManyPixels() async {
        let r = await ChainRunner.apply(ChainStep(block: .resizePhoto, settings: ["size": "413x531"]), to: .image(photo(1200, 900)))
        guard case .success(.image(let out)) = r else { return XCTFail("no image") }
        XCTAssertEqual(out.size.width * out.scale, 413); XCTAssertEqual(out.size.height * out.scale, 531)
    }
    func testExactSizeBlockExplainsABadSize() async {
        let r = await ChainRunner.apply(ChainStep(block: .resizePhoto, settings: ["size": "huge"]), to: .image(photo(100, 100)))
        guard case .failure(.invalid(let why)) = r else { return XCTFail("should stop") }
        XCTAssertTrue(why.contains("600x600"))
    }
    func testWatermarkLineHasWordsAndTheDay() {
        let day = Date(timeIntervalSince1970: 1_794_441_600)   // 12 Nov 2026 UTC
        XCTAssertTrue(ChainImage.watermarkLine("For Acme Bank only", on: day).hasPrefix("For Acme Bank only · "))
        XCTAssertTrue(ChainImage.watermarkLine("", on: day).hasPrefix("For verification only · "))
        XCTAssertTrue(ChainImage.watermarkLine("", on: day).hasSuffix("2026"))
    }
    func testWatermarkKeepsTheSizeAndChangesThePicture() async {
        let src = photo(400, 300)
        let r = await ChainRunner.apply(ChainStep(block: .watermark, settings: ["text": "Copy"]), to: .image(src))
        guard case .success(.image(let out)) = r else { return XCTFail("no image") }
        XCTAssertEqual(out.size, src.size)
        XCTAssertNotEqual(out.pngData(), src.pngData(), "the words must actually be drawn")
    }
    func testLimitLabels() {
        XCTAssertEqual(ChainImage.limitLabel(0.05), "50 KB"); XCTAssertEqual(ChainImage.limitLabel(0.02), "20 KB"); XCTAssertEqual(ChainImage.limitLabel(2), "2 MB")
    }
    func testPortalPhotoTemplateLandsUnderFiftyKilobytesAtExactSize() async throws {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "portal-photo" })
        let r = await ChainRunner.run(c, input: .image(photo(3000, 2000)))
        guard case .success(.file(let d, let ext)) = r else { return XCTFail("no file") }
        XCTAssertEqual(ext, "jpg")
        XCTAssertLessThanOrEqual(d.count, 50 * 1024)
    }
    func testPlannerUnderstandsKilobytesAndWatermark() {
        let kb = ChainPlanner.keywordPlan("shrink my photo under 50 kb for the visa upload")
        XCTAssertEqual(kb?.steps.map(\.block), [.shrinkImage]); XCTAssertEqual(kb?.steps.first?.settings["mb"], "0.05")
        XCTAssertEqual(ChainPlanner.keywordPlan("add a watermark to my licence copy and strip the location")?.steps.map(\.block), [.watermark, .stripLocation])
    }
}

/// Many pages or photos into one PDF.
final class CombineTests: XCTestCase {
    private func page(_ c: UIColor) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 200, height: 280), format: f).image { ctx in c.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 280)) }
    }
    private func pageCount(_ p: ChainPayload?) -> Int? {
        guard case .file(let d, let ext)? = p, ext == "pdf" else { return nil }
        return PDFDocument(data: d)?.pageCount
    }
    func testPicturesBecomeOnePdfWithAPageEach() {
        XCTAssertEqual(pageCount(ChainCombine.onePDF([.image(page(.white)), .image(page(.gray)), .image(page(.black))])), 3)
    }
    func testSeparatePdfsAreJoinedInOrder() async {
        var parts: [ChainPayload] = []
        for c in [UIColor.white, UIColor.gray] {
            if case .success(let p) = await ChainRunner.apply(ChainStep(block: .photoPdf), to: .image(page(c))) { parts.append(p) }
        }
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(pageCount(ChainCombine.onePDF(parts)), 2)
    }
    func testSavedPhotosCombineToo() {
        let jpg = page(.white).jpegData(compressionQuality: 0.8)!
        XCTAssertEqual(pageCount(ChainCombine.onePDF([.file(jpg, ext: "jpg"), .file(jpg, ext: "jpg")])), 2)
    }
    func testTextOrMixedResultsAreLeftSeparate() {
        XCTAssertNil(ChainCombine.onePDF([.text("a"), .text("b")]))
        XCTAssertNil(ChainCombine.onePDF([.image(page(.white)), .text("b")]))
        XCTAssertNil(ChainCombine.onePDF([]))
    }
    func testCombineFlagSurvivesSavingAndOldToolsLoadWithoutIt() throws {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "scan-to-pdf" })
        XCTAssertEqual(c.combine, true)
        XCTAssertEqual(try JSONDecoder().decode(Chain.self, from: JSONEncoder().encode(c)).combine, true)
        let old = #"{"id":"a","name":"Old","steps":[{"block":"photoPdf","settings":{}}]}"#
        XCTAssertNil(try JSONDecoder().decode(Chain.self, from: Data(old.utf8)).combine)
    }
}

/// Sign and stamp: where the marks go, and what the files are called.
final class StampAndNameTests: XCTestCase {
    func testPlanRoundTripsAndStandardIsSignaturePlusDate() {
        let p = StampPlan.standard
        XCTAssertEqual(p.spots.map(\.mark), [.signature, .date])
        XCTAssertEqual(p.text, "sig@0.720,0.880,0.300;date@0.250,0.880,0.220")
        XCTAssertEqual(StampPlan(p.text), p)
    }
    func testPlanSkipsRubbishClampsToThePageAndCountsAMarkOnce() {
        let p = StampPlan("sig@1.4,-0.2,5;bogus@0.1,0.1,0.1;date@0.5,0.5;sig@0.1,0.1,0.2; name @ 0.3, 0.4 ,0.25")
        XCTAssertEqual(p.spots.map(\.mark), [.signature, .name])
        XCTAssertEqual(p.spots[0], StampPlan.Spot(mark: .signature, x: 1, y: 0, w: 0.9))
        XCTAssertEqual(p.spots[1], StampPlan.Spot(mark: .name, x: 0.3, y: 0.4, w: 0.25))
        XCTAssertTrue(StampPlan("").spots.isEmpty)
    }
    func testTurningMarksOnAndOffAndMoving() {
        var p = StampPlan.standard
        p.set(.name, on: true); p.set(.name, on: true)
        XCTAssertEqual(p.spots.map(\.mark), [.signature, .date, .name], "turning on twice adds once")
        p.set(.date, on: false)
        XCTAssertFalse(p.has(.date))
        p.move(.signature, x: 0.4, y: 1.7)
        XCTAssertEqual(p.spots[0].x, 0.4); XCTAssertEqual(p.spots[0].y, 1, "kept on the page")
    }
    func testDateOnlyStampChangesThePageAndKeepsItsSize() async {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        let page = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 520), format: f).image { c in UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 520)) }
        let r = await ChainRunner.apply(ChainStep(block: .stamp, settings: ["marks": "date@0.5,0.5,0.4"]), to: .image(page))
        guard case .success(.image(let out)) = r else { return XCTFail("no image") }
        XCTAssertEqual(out.size.width * out.scale, 400); XCTAssertEqual(out.size.height * out.scale, 520)
        XCTAssertNotEqual(out.pngData(), page.pngData(), "the date must be drawn on the page")
    }
    func testStampWithNothingTurnedOnSaysSo() async {
        let r = await ChainRunner.apply(ChainStep(block: .stamp, settings: ["marks": ""]), to: .image(UIImage()))
        guard case .failure(.invalid(let why)) = r else { return XCTFail("should stop") }
        XCTAssertTrue(why.contains("nothing to place"))
    }
    func testFileNames() {
        let day = Date(timeIntervalSince1970: 1_794_484_800)   // 12 Nov 2026, midday UTC
        let ymd: String = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: day) }()
        XCTAssertEqual(ChainName.file(pattern: "Signed form {date}", tool: "x", day: day, ext: "pdf"), "Signed form \(ymd).pdf")
        XCTAssertEqual(ChainName.file(pattern: "{tool} {date}", tool: "Rent receipt", day: day, index: 2, ext: "jpg"), "Rent receipt \(ymd)-2.jpg")
        XCTAssertEqual(ChainName.file(pattern: nil, tool: "x", ext: "pdf"), "Tenzy-result.pdf")
        XCTAssertEqual(ChainName.file(pattern: "  ", tool: "x", index: 3, ext: "jpg"), "Tenzy-3.jpg")
        XCTAssertEqual(ChainName.file(pattern: "a/b\\c:d*e?f\"g<h>i|j", tool: "x", ext: "pdf"), "abcdefghij.pdf", "characters a file name can't hold are dropped")
        XCTAssertEqual(ChainName.file(pattern: "..hidden.", tool: "x", ext: "pdf"), "hidden.pdf")
        XCTAssertEqual(ChainName.file(pattern: String(repeating: "n", count: 200), tool: "x", ext: "pdf").count, 84)
    }
    func testSignAndSendStarterIsWiredForPaperwork() throws {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "sign-and-send" })
        XCTAssertEqual(c.steps.map(\.block), [.stamp, .photoPdf])
        XCTAssertEqual(c.combine, true); XCTAssertEqual(c.finish?.kind, .mail); XCTAssertEqual(c.fileName, "Signed form {date}")
        XCTAssertNil(c.problem(starting: .image))
    }
}

/// The running expense sheet: one row per receipt, added to the same list.
final class RunningListTests: XCTestCase {
    func testFirstRowsKeepTheirHeaderLaterRowsDontRepeatIt() {
        let first = RunningList.merged(existing: "", incoming: "Date,Merchant,Total\n2026-11-10,Blue Door Cafe,7.75")
        XCTAssertEqual(first, "Date,Merchant,Total\n2026-11-10,Blue Door Cafe,7.75")
        let second = RunningList.merged(existing: first, incoming: "Date,Merchant,Total\n2026-11-11,Hardware Hut,23.10\n")
        XCTAssertEqual(second, "Date,Merchant,Total\n2026-11-10,Blue Door Cafe,7.75\n2026-11-11,Hardware Hut,23.10")
    }
    func testTwoIdenticalPurchasesAreBothKept() {
        let once = RunningList.merged(existing: "H\na,1", incoming: "H\na,1")
        XCTAssertEqual(once, "H\na,1\na,1")
    }
    func testBlankLinesAndEmptyInputs() {
        XCTAssertEqual(RunningList.merged(existing: "H\n\n a,1 \n", incoming: "\n\nb,2"), "H\na,1\nb,2")
        XCTAssertEqual(RunningList.merged(existing: "H\na,1", incoming: "  "), "H\na,1")
        XCTAssertEqual(RunningList.merged(existing: "", incoming: ""), "")
    }
    func testPreviewNeverSavesButARealRunDoes() async {
        let list = "Test list \(UUID().uuidString)"
        let file = ChainName.file(pattern: list, tool: "List", ext: "csv")
        defer { RunningList.delete(file) }
        let step = ChainStep(block: .addToList, settings: ["list": list])
        _ = await ChainRunner.apply(step, to: .text("H\na,1"), dryRun: true)
        XCTAssertEqual(RunningList.read(file), "", "a preview must not write")
        _ = await ChainRunner.apply(step, to: .text("H\na,1"))
        let r = await ChainRunner.apply(step, to: .text("H\nb,2"))
        guard case .success(.file(let d, let ext)) = r else { return XCTFail("no sheet") }
        XCTAssertEqual(ext, "csv")
        XCTAssertEqual(String(decoding: d, as: UTF8.self), "H\na,1\nb,2")
        XCTAssertEqual(RunningList.read(file), "H\na,1\nb,2")
    }
    func testMonthTokenInSheetName() {
        let day = Date(timeIntervalSince1970: 1_794_484_800)
        let ym: String = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM"; return f.string(from: day) }()
        XCTAssertEqual(ChainName.file(pattern: "Expenses {month}", tool: "List", day: day, ext: "csv"), "Expenses \(ym).csv")
    }
    func testReceiptRunStarterChainsAndPlannerFindsIt() throws {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "receipt-run" })
        XCTAssertEqual(c.steps.map(\.block), [.readText, .expenseRow, .addToList]); XCTAssertNil(c.problem(starting: .image))
        XCTAssertEqual(ChainPlanner.keywordPlan("add every receipt to my expense sheet")?.steps.map(\.block), [.readText, .expenseRow, .addToList])
    }
    func testExpenseRowIsHeaderPlusOneRow() async {
        let r = await ChainRunner.apply(ChainStep(block: .expenseRow), to: .text("Blue Door Cafe\nLatte 4.50\nMuffin 3.25\nTotal 7.75"))
        guard case .success(.text(let out)) = r else { return XCTFail("no row") }
        let lines = out.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2); XCTAssertEqual(lines[0], "Date,Merchant,Total,Tax,Currency"); XCTAssertTrue(lines[1].contains("7.75"))
    }
}

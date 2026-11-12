import XCTest
import AppIntents
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
    func testTwentyEightTemplatesAllValidAndUnique() {
        XCTAssertEqual(ChainTemplates.all.count, 63)
        XCTAssertEqual(Set(ChainTemplates.all.map(\.id)).count, ChainTemplates.all.count)
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
        XCTAssertEqual(Block.grouped(text).map(\.goal), ["Paperwork", "Read what's in it", "Understand it", "Clean it up", "Turn it into something", "Money"])
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

/// WhatsApp without saving a number, a contact as a QR code, and both sides of an ID on one page.
final class PeopleAndIdTests: XCTestCase {
    func testChatLinkAddsTheCountryCodeOnlyWhenItIsMissing() {
        XCTAssertEqual(ChainText.chatLink("(312) 555-0147", countryCode: "1"), "https://wa.me/13125550147")
        XCTAssertEqual(ChainText.chatLink("+44 20 7946 0958", countryCode: "1"), "https://wa.me/442079460958")
        XCTAssertEqual(ChainText.chatLink("0044 20 7946 0958", countryCode: "1"), "https://wa.me/442079460958")
        XCTAssertEqual(ChainText.chatLink("07911 123456", countryCode: "44"), "https://wa.me/447911123456")
        XCTAssertEqual(ChainText.chatLink("919876543210", countryCode: "1"), "https://wa.me/919876543210", "already has its country code")
        XCTAssertEqual(ChainText.chatLink("Courier: call 312 555 0147 at the gate", countryCode: "+1"), "https://wa.me/13125550147")
    }
    func testChatLinkWithNoNumberIsNil() {
        XCTAssertNil(ChainText.chatLink("call me later", countryCode: "1"))
        XCTAssertNil(ChainText.chatLink("12345", countryCode: "1"))
    }
    func testCallingCodes() {
        XCTAssertEqual(ChainText.callingCode(region: "IN"), "91"); XCTAssertEqual(ChainText.callingCode(region: "us"), "1")
        XCTAssertEqual(ChainText.callingCode(region: nil), "1"); XCTAssertEqual(ChainText.callingCode(region: "ZZ"), "1")
    }
    func testChatLinkBlockAndItsStarterEndByOpening() async throws {
        let r = await ChainRunner.apply(ChainStep(block: .chatLink, settings: ["cc": "91"]), to: .text("98765 43210"))
        guard case .success(.text(let link)) = r else { return XCTFail("no link") }
        XCTAssertEqual(link, "https://wa.me/919876543210")
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "whatsapp-no-save" })
        XCTAssertEqual(c.finish?.kind, .open); XCTAssertEqual(c.finish?.label, "Open it")
    }
    func testContactQrNeedsAWayToReachThePerson() async {
        let ok = await ChainRunner.apply(ChainStep(block: .contactQr), to: .text("Priya Shah\npriya@studio.example"))
        guard case .success(.image(let img)) = ok else { return XCTFail("no code") }
        XCTAssertGreaterThan(img.size.width, 100)
        let none = await ChainRunner.apply(ChainStep(block: .contactQr), to: .text("Just a name"))
        XCTAssertEqual(none.failureValue, .nothingFound(.businessCard))
    }
    func testSlotsStackDownThePageInsideTheMargins() {
        let s = ChainImage.slots(count: 2, in: CGSize(width: 1000, height: 1400), margin: 100)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s[0], CGRect(x: 100, y: 100, width: 800, height: 550))
        XCTAssertEqual(s[1], CGRect(x: 100, y: 750, width: 800, height: 550))
        XCTAssertTrue(ChainImage.slots(count: 0, in: CGSize(width: 10, height: 10), margin: 1).isEmpty)
    }
    func testBothSidesOfAnIdBecomeOnePageNotTwo() {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        let card = UIGraphicsImageRenderer(size: CGSize(width: 856, height: 540), format: f).image { c in UIColor.gray.setFill(); c.fill(CGRect(x: 0, y: 0, width: 856, height: 540)) }
        func pages(_ p: ChainPayload?) -> Int? { if case .file(let d, _)? = p { return PDFDocument(data: d)?.pageCount }; return nil }
        XCTAssertEqual(pages(ChainCombine.onePDF([.image(card), .image(card)], onePage: true)), 1)
        XCTAssertEqual(pages(ChainCombine.onePDF([.image(card), .image(card)])), 2)
        XCTAssertEqual(ChainImage.sheet([card, card]).size, CGSize(width: 1240, height: 1754))
    }
    func testIdStarterIsWired() throws {
        let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == "id-both-sides" })
        XCTAssertEqual(c.combine, true); XCTAssertEqual(c.onePage, true); XCTAssertNil(c.problem(starting: .image))
    }
}

final class ScheduleTests: XCTestCase {
    func testLabelsReadLikeAPersonWouldSayThem() {
        XCTAssertEqual(ChainSchedule().label(), "Every day at 9:00 AM")
        XCTAssertEqual(ChainSchedule(hour: 18, minute: 30, days: [2, 3, 4, 5, 6]).label(), "Weekdays at 6:30 PM")
        XCTAssertEqual(ChainSchedule(hour: 18, minute: 30, days: [2, 3, 4, 5, 6]).label(uses24h: true), "Weekdays at 18:30")
        XCTAssertEqual(ChainSchedule(hour: 0, minute: 5, days: [7, 1]).label(), "Weekends at 12:05 AM")
        XCTAssertEqual(ChainSchedule(hour: 12, minute: 0, days: [1, 5, 2]).label(), "Mon, Thu, Sun at 12:00 PM")
        XCTAssertEqual(ChainSchedule(hour: 8, minute: 0, days: [1, 2, 3, 4, 5, 6, 7]).label(), "Every day at 8:00 AM")
    }
    func testOneReminderADayOrOnePerChosenDay() {
        XCTAssertEqual(ChainSchedule(hour: 7, minute: 15, days: []).triggers, [DateComponents(hour: 7, minute: 15)])
        let t = ChainSchedule(hour: 7, minute: 15, days: [6, 2, 2, 9]).triggers
        XCTAssertEqual(t, [DateComponents(hour: 7, minute: 15, weekday: 2), DateComponents(hour: 7, minute: 15, weekday: 6)])
        XCTAssertEqual(ChainSchedule(hour: 40, minute: -3, days: []).triggers, [DateComponents(hour: 23, minute: 0)])
    }
    func testOldToolsLoadAndAScheduleSurvivesSaving() throws {
        let old = try JSONDecoder().decode(Chain.self, from: Data(#"{"id":"a","name":"Old","steps":[]}"#.utf8))
        XCTAssertNil(old.schedule)
        var c = Chain(id: "b", name: "Friday receipts", steps: [ChainStep(block: .readText)])
        c.schedule = ChainSchedule(hour: 18, minute: 0, days: [6])
        let back = try JSONDecoder().decode(Chain.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(back, c)
        let loose = try JSONDecoder().decode(Chain.self, from: Data(#"{"id":"a","name":"Loose","steps":[],"schedule":{"hour":7}}"#.utf8))
        XCTAssertEqual(loose.schedule, ChainSchedule(hour: 7, minute: 0, days: []))
    }
    func testASharedToolDoesNotCarryItsReminder() throws {
        var c = Chain(id: "b", name: "Friday receipts", steps: [ChainStep(block: .readText)])
        c.schedule = ChainSchedule(hour: 18, minute: 0, days: [6])
        XCTAssertFalse(c.shareText.contains("schedule"))
        XCTAssertNil(try XCTUnwrap(Chain.imported(from: c.shareText)).schedule)
    }
    func testReminderPlanNamesEachOneAndStaysUnderThePhoneLimit() {
        var a = Chain(id: "a", name: "A", steps: [ChainStep(block: .readText)]); a.schedule = ChainSchedule(hour: 9, minute: 0, days: [2, 4])
        let b = Chain(id: "b", name: "B", steps: [ChainStep(block: .readText)])
        let p = ToolSchedules.plan(for: [a, b])
        XCTAssertEqual(p.map(\.id), ["tool-a-0", "tool-a-1"])
        XCTAssertEqual(p[1].when.weekday, 4)
        let many = (0..<20).map { i -> Chain in var c = a; c.id = "t\(i)"; c.schedule = ChainSchedule(hour: 9, minute: 0, days: [1, 2, 3, 4, 5, 6]); return c }
        XCTAssertEqual(ToolSchedules.plan(for: many).count, ToolSchedules.limit)
    }
}

final class ShortcutActionTests: XCTestCase {
    func testResultsLeaveAsNamedFiles() throws {
        var c = Chain(id: "x", name: "Clean up", steps: [ChainStep(block: .cleanText)])
        let t = try XCTUnwrap(ToolIntentSupport.file(.text("hello"), chain: c))
        XCTAssertEqual(t.name, "Tenzy-result.txt"); XCTAssertEqual(String(decoding: t.data, as: UTF8.self), "hello")
        c.fileName = "Notes {tool}"
        XCTAssertEqual(ToolIntentSupport.file(.file(Data([1, 2]), ext: "pdf"), chain: c)?.name, "Notes Clean up.pdf")
    }
    func testEveryStarterIsOfferedAndFailuresAreOneSentence() {
        let ids = ToolIntentSupport.all().map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ChainTemplates.all.allSatisfy { ids.contains($0.id) })
        XCTAssertEqual(ToolIntentSupport.words(.nothingFound(.readText)), "\(Block.readText.title) didn't find anything to work with.")
        XCTAssertThrowsError(try ToolIntentSupport.chain("no-such-tool"))
    }
    func testAToolRunsStartToFinishForShortcuts() async throws {
        let c = Chain(id: "x", name: "Tidy", steps: [ChainStep(block: .cleanText)])
        let f = try await ToolIntentSupport.run(c, on: .text("a   b\n\n\n\na   b\nc"))
        XCTAssertEqual(String(decoding: f.data, as: UTF8.self), "a b\n\nc")
        XCTAssertEqual(f.filename, "Tenzy-result.txt")
    }
}

final class SheetsTests: XCTestCase {
    func testRowCountIgnoresTheHeaderAndBlankLines() {
        XCTAssertEqual(RunningList.rowCount(""), 0)
        XCTAssertEqual(RunningList.rowCount("Date,Merchant,Total"), 0)
        XCTAssertEqual(RunningList.rowCount("Date,Merchant,Total\n2026-11-01,Cafe,4.50\n\n2026-11-02,Fuel,40\n"), 2)
    }
    func testSheetsCanBeListedRenamedTrimmedAndDeleted() {
        let file = "Unit test sheet \(UUID().uuidString).csv"
        XCTAssertTrue(RunningList.write(file, "Date,Merchant,Total\n2026-11-01,Cafe,4.50\n2026-11-02,Fuel,40"))
        XCTAssertEqual(RunningList.all().first { $0.file == file }?.rows, 2)
        XCTAssertTrue(RunningList.removeLastRow(file))
        XCTAssertEqual(RunningList.read(file), "Date,Merchant,Total\n2026-11-01,Cafe,4.50")
        XCTAssertTrue(RunningList.removeLastRow(file)); XCTAssertFalse(RunningList.removeLastRow(file))     // the header always stays
        XCTAssertNil(RunningList.rename(file, to: "  "))
        let other = "Renamed \(UUID().uuidString)"
        let moved = RunningList.rename(file, to: other)
        XCTAssertEqual(moved, other + ".csv")
        XCTAssertNil(RunningList.all().first { $0.file == file })
        XCTAssertEqual(RunningList.all().first { $0.file == other + ".csv" }?.name, other)
        RunningList.delete(other + ".csv")
        XCTAssertNil(RunningList.all().first { $0.file == other + ".csv" })
    }
    func testSummaryReadsPlainly() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(SheetsView.summary(rows: 0, changed: now, now: now, calendar: cal), "No entries yet · changed today")
        XCTAssertEqual(SheetsView.summary(rows: 1, changed: now.addingTimeInterval(-86_400), now: now, calendar: cal), "1 entry · changed yesterday")
        XCTAssertEqual(SheetsView.summary(rows: 12, changed: now.addingTimeInterval(-5 * 86_400), now: now, calendar: cal), "12 entries · changed 5 days ago")
    }
}

final class InputTests: XCTestCase {
    func testNewWordsGoUnderWhatIsThere() {
        XCTAssertEqual(InputText.joined("", " hello \n"), "hello")
        XCTAssertEqual(InputText.joined("one\n\n", "\ntwo"), "one\ntwo")
        XCTAssertEqual(InputText.joined("one", "  "), "one")
    }
    func testAContactBecomesLinesTheTextStepsCanRead() async {
        let t = InputText.contact(name: "Priya Shah", company: "", phones: ["+1 415 555 0134"], emails: ["priya@studio.example"])
        XCTAssertEqual(t, "Priya Shah\n+1 415 555 0134\npriya@studio.example")
        let r = await ChainRunner.apply(ChainStep(block: .contactQr), to: .text(t))
        guard case .success(.image) = r else { return XCTFail("a picked contact should make a QR code") }
    }
    func testAPdfGivesItsWordsAndItsPages() throws {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { c in
            for line in ["Invoice 1042", "Second page"] {
                c.beginPage()
                (line as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("input-test-\(UUID().uuidString).pdf")
        try data.write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let words = try XCTUnwrap(PDFInput.text(from: url))
        XCTAssertTrue(words.contains("Invoice 1042")); XCTAssertTrue(words.contains("Second page"))
        let pages = PDFInput.pages(from: url)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].size.width / pages[0].size.height, 612.0 / 792.0, accuracy: 0.01)
        XCTAssertEqual(max(pages[0].size.width, pages[0].size.height), 2000, accuracy: 2)
        XCTAssertEqual(PDFInput.pages(from: url, limit: 1).count, 1)
        XCTAssertNil(PDFInput.text(from: FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).pdf")))
    }
}

final class IntroTests: XCTestCase {
    func testStartersCanBeNarrowedToWhatYouHave() {
        let photo = BuilderIntro.starters(for: .image), text = BuilderIntro.starters(for: .text)
        XCTAssertFalse(photo.isEmpty); XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(photo.allSatisfy { $0.steps.first?.block.takes == .image })
        XCTAssertTrue(text.allSatisfy { $0.steps.first?.block.takes == .text })
        let video = BuilderIntro.starters(for: .video)
        XCTAssertFalse(video.isEmpty); XCTAssertTrue(video.allSatisfy { $0.steps.first?.block.takes == .video })
        let sound = BuilderIntro.starters(for: .audio), pdf = BuilderIntro.starters(for: .pdf)
        XCTAssertFalse(sound.isEmpty); XCTAssertFalse(pdf.isEmpty)
        XCTAssertEqual(photo.count + text.count + video.count + sound.count + pdf.count, ChainTemplates.all.count)
        XCTAssertEqual(BuilderIntro.starters(for: nil), ChainTemplates.all)
    }
    func testTheDemoStarterExistsAndTheIntroIsThreeIdeas() {
        XCTAssertNotNil(ChainTemplates.all.first { $0.id == BuilderIntro.demoID })
        XCTAssertEqual(BuilderIntro.pages.count, 3)
    }
}

final class WifiTests: XCTestCase {
    func testFindsTheNetworkAndPasswordHoweverTheSignWritesThem() {
        var w = ChainText.wifi(in: "Welcome!\nNetwork: CafeGuest\nPassword: latte1234\nEnjoy")
        XCTAssertEqual(w?.name, "CafeGuest"); XCTAssertEqual(w?.password, "latte1234")
        w = ChainText.wifi(in: "WiFi = Home 5G / PW: p@ss:word;1")
        XCTAssertEqual(w?.name, "Home 5G"); XCTAssertEqual(w?.password, "p@ss:word;1")
        w = ChainText.wifi(in: "SSID: Lobby")
        XCTAssertEqual(w?.name, "Lobby"); XCTAssertEqual(w?.password, "")
        w = ChainText.wifi(in: "MyNet\nsecret99")
        XCTAssertEqual(w?.name, "MyNet"); XCTAssertEqual(w?.password, "secret99")
        XCTAssertNil(ChainText.wifi(in: "Password: only"))
        XCTAssertNil(ChainText.wifi(in: "Network problems today, sorry"))
        XCTAssertNil(ChainText.wifi(in: ""))
    }
    func testTheCodeEscapesAwkwardCharactersAndMarksOpenNetworks() {
        XCTAssertEqual(ChainText.wifiCode("Network: CafeGuest\nPassword: latte1234"), "WIFI:T:WPA;S:CafeGuest;P:latte1234;;")
        XCTAssertEqual(ChainText.wifiCode("WiFi = Home 5G / PW: p@ss:word;1"), "WIFI:T:WPA;S:Home 5G;P:p@ss\\:word\\;1;;")
        XCTAssertEqual(ChainText.wifiCode("SSID: Lobby"), "WIFI:T:nopass;S:Lobby;;")
    }
    func testTheStepMakesACodeAndTheStarterIsWired() async throws {
        let r = await ChainRunner.apply(ChainStep(block: .wifiQr), to: .text("Network: CafeGuest\nPassword: latte1234"))
        guard case .success(.image(let img)) = r else { return XCTFail("no code") }
        XCTAssertGreaterThan(img.size.width, 100)
        let none = await ChainRunner.apply(ChainStep(block: .wifiQr), to: .text("nothing useful here at all"))
        XCTAssertEqual(none.failureValue, .nothingFound(.wifiQr))
        XCTAssertNil(try XCTUnwrap(ChainTemplates.all.first { $0.id == "wifi-sign" }).problem(starting: .image))
    }
}

final class ReturnByTests: XCTestCase {
    func testDeadlineIsNineInTheMorningSoManyDaysAfterTheReceipt() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let bought = cal.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 17, minute: 40))!
        let due = ChainText.returnDeadline(purchased: bought, days: 30, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day, .hour, .minute], from: due), DateComponents(year: 2026, month: 12, day: 12, hour: 9, minute: 0))
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 8))!
        let noDate = ChainText.returnDeadline(purchased: nil, days: 14, now: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.month, .day, .hour], from: noDate), DateComponents(month: 2, day: 14, hour: 9))
    }
    func testWordingAndSettings() {
        XCTAssertEqual(ChainText.returnTitle(" Corner Hardware "), "Last day to return: Corner Hardware")
        XCTAssertEqual(ChainText.returnTitle(""), "Last day to return")
        XCTAssertEqual(ChainText.returnDays(nil), 30); XCTAssertEqual(ChainText.returnDays("60"), 60)
        XCTAssertEqual(ChainText.returnDays("0"), 1); XCTAssertEqual(ChainText.returnDays("9999"), 365); XCTAssertEqual(ChainText.returnDays("soon"), 30)
    }
    func testStepNeedsAReceiptAndTheStarterIsWired() async throws {
        let none = await ChainRunner.apply(ChainStep(block: .returnBy), to: .text("hello there"))
        XCTAssertEqual(none.failureValue, .nothingFound(.returnBy))
        let ok = await ChainRunner.apply(ChainStep(block: .returnBy, settings: ["days": "90"]), to: .text("Corner Hardware\nHammer 12.99\nTotal 12.99"))
        guard case .success(.file(let d, let ext)) = ok else { return XCTFail("no calendar entry") }
        XCTAssertEqual(ext, "ics")
        XCTAssertTrue(String(decoding: d, as: UTF8.self).contains("SUMMARY:Last day to return"))
        XCTAssertNil(try XCTUnwrap(ChainTemplates.all.first { $0.id == "return-by" }).problem(starting: .image))
    }
}

final class VideoTests: XCTestCase {
    func testVideoStepsOnlyFitAVideoAndSayWhatTheyGive() {
        let v: [Block] = [.videoShrink, .videoStill, .videoMute, .videoAudio, .videoTrim, .videoGif, .videoRotate, .videoVertical, .videoCaptions, .videoSpeed, .videoLoop]
        XCTAssertTrue(v.allSatisfy { $0.takes == .video })
        XCTAssertEqual(Block.starting(with: .video), v)
        XCTAssertFalse(Block.starting(with: .image).contains(.videoShrink)); XCTAssertFalse(Block.starting(with: .text).contains(.videoStill))
        XCTAssertEqual(Block.videoShrink.gives, .video); XCTAssertEqual(Block.videoMute.gives, .video)
        XCTAssertEqual(Block.videoStill.gives, .image); XCTAssertEqual(Block.videoAudio.gives, .audio)
        XCTAssertEqual(ChainKind.video.label, "a video")
    }
    func testStepsChainOnlyWhereTheKindsMeet() {
        let quietThenSmall = Chain(id: "a", name: "A", steps: [ChainStep(block: .videoMute), ChainStep(block: .videoShrink)])
        XCTAssertNil(quietThenSmall.problem(starting: .video))
        XCTAssertNotNil(quietThenSmall.problem(starting: .image))
        let stillThenRead = Chain(id: "b", name: "B", steps: [ChainStep(block: .videoStill), ChainStep(block: .readText), ChainStep(block: .summarize)])
        XCTAssertNil(stillThenRead.problem(starting: .video))
        let wrong = Chain(id: "c", name: "C", steps: [ChainStep(block: .videoAudio), ChainStep(block: .videoShrink)])
        XCTAssertNotNil(wrong.problem(starting: .video))
    }
    func testVideoStartersAreValidAndSurviveCopying() throws {
        for id in ["video-email", "video-chat", "video-still", "video-quiet"] {
            let c = try XCTUnwrap(ChainTemplates.all.first { $0.id == id }, id)
            XCTAssertNil(c.problem(starting: .video), id)
            XCTAssertEqual(try XCTUnwrap(Chain.imported(from: c.shareText)).steps, c.steps)
        }
        XCTAssertEqual(ChainTemplates.all.first { $0.id == "video-email" }?.finish?.kind, .mail)
    }
    func testSizeLimitSetting() {
        XCTAssertEqual(ChainText.videoLimit(nil), 25); XCTAssertEqual(ChainText.videoLimit("16"), 16); XCTAssertEqual(ChainText.videoLimit("16.0"), 16)
        XCTAssertEqual(ChainText.videoLimit("0"), 1); XCTAssertEqual(ChainText.videoLimit("junk"), 25)
        XCTAssertTrue(ChainText.videoLimits.contains(25))
    }
    func testDescribeItUnderstandsVideoJobs() {
        func blocks(_ ask: String) -> [Block] { ChainPlanner.keywordPlan(ask)?.steps.map(\.block) ?? [] }
        XCTAssertEqual(blocks("make this video small enough to email"), [.videoShrink])
        XCTAssertEqual(ChainPlanner.keywordPlan("shrink a video for whatsapp")?.steps.first?.settings["mb"], "16")
        XCTAssertEqual(ChainPlanner.keywordPlan("get my video under 50 mb")?.steps.first?.settings["mb"], "50")
        XCTAssertEqual(blocks("video without sound"), [.videoMute])
        XCTAssertEqual(blocks("mute the video and shrink it"), [.videoMute, .videoShrink])
        XCTAssertEqual(blocks("grab a still from a video"), [.videoStill])
        XCTAssertEqual(blocks("just the audio from this video"), [.videoAudio])
        XCTAssertEqual(blocks("shrink a photo under 1 mb"), [.shrinkImage])
    }
}

final class ShareEndingTests: XCTestCase {
    func testOnlyEmailAndMessageEndingsAreOfferedInTheShareSheet() {
        var c = Chain(id: "a", name: "A", steps: [ChainStep(block: .stripLocation)])
        XCTAssertNil(ShareEnding.of(c)); XCTAssertNil(ShareEnding.of(nil))
        c.finish = ChainFinish(kind: .mail, to: "me@example.com")
        XCTAssertEqual(ShareEnding.of(c)?.label, "Email it to me@example.com")
        c.finish = ChainFinish(kind: .message, to: ""); XCTAssertEqual(ShareEnding.of(c)?.kind, .message)
        c.finish = ChainFinish(kind: .share, to: ""); XCTAssertNil(ShareEnding.of(c))
        c.finish = ChainFinish(kind: .open, to: ""); XCTAssertNil(ShareEnding.of(c))
    }
}

/// Recordings, PDFs, links, codes, translating, collages and the extra video steps: how the kinds fit together and
/// the plain rules behind each step.
final class NewKindTests: XCTestCase {
    private func chain(_ blocks: [Block]) -> Chain { Chain(id: "t", name: "T", steps: blocks.map { ChainStep(block: $0) }) }

    func testAFileIsARecordingAPdfOrAPhotoByItsEnding() {
        XCTAssertTrue(ChainPayload.isAudio("M4A")); XCTAssertTrue(ChainPayload.isAudio("wav")); XCTAssertFalse(ChainPayload.isAudio("pdf")); XCTAssertFalse(ChainPayload.isAudio("mp4"))
        XCTAssertEqual(ChainKind.audio.label, "a recording"); XCTAssertEqual(ChainKind.pdf.label, "a PDF")
        XCTAssertFalse(ChainKind.pdf.feeds(.image)); XCTAssertFalse(ChainKind.audio.feeds(.video)); XCTAssertTrue(ChainKind.pdf.feeds(.pdf))
    }
    func testNewStepsFitOnlyTheirOwnKind() {
        XCTAssertEqual(Block.starting(with: .audio), [.speechText, .voiceChange])
        XCTAssertEqual(Block.starting(with: .pdf), [.pdfShrink, .pdfLock, .pdfPages, .pdfText])
        XCTAssertTrue(Block.starting(with: .image).contains(.readCode)); XCTAssertTrue(Block.starting(with: .text).contains(.translate))
        XCTAssertEqual(Block.photoPdf.gives, .pdf); XCTAssertEqual(Block.textPdf.gives, .pdf); XCTAssertEqual(Block.readAloud.gives, .audio)
        XCTAssertEqual(Block.videoGif.gives, .file); XCTAssertEqual(Block.videoCaptions.gives, .video)
    }
    func testStepsChainAcrossTheNewKinds() {
        XCTAssertNil(chain([.videoAudio, .speechText, .actionItems]).problem(starting: .video))
        XCTAssertNil(chain([.photoPdf, .pdfLock]).problem(starting: .image))
        XCTAssertNil(chain([.pageText, .textPdf, .pdfShrink]).problem(starting: .text))
        XCTAssertNil(chain([.readCode, .cleanLinks, .makeQr]).problem(starting: .image))
        XCTAssertNil(chain([.pdfText, .translate, .readAloud]).problem(starting: .pdf))
        XCTAssertNotNil(chain([.speechText]).problem(starting: .pdf))
        XCTAssertNotNil(chain([.pdfLock]).problem(starting: .image))
        XCTAssertNotNil(chain([.videoGif, .videoShrink]).problem(starting: .video), "a GIF is a finished file, not a video")
    }
    func testEveryStepHasAGoalTheBuilderShows() {
        for b in Block.allCases { XCTAssertTrue(Block.goalOrder.contains(b.goal), b.rawValue) }
        XCTAssertEqual(Set(Block.allCases.map(\.rawValue)).count, Block.allCases.count)
    }
    func testPageListReadsRangesAndIgnoresJunk() {
        XCTAssertEqual(ChainText.pageList("1-3, 5", count: 10), [0, 1, 2, 4])
        XCTAssertEqual(ChainText.pageList("", count: 3), [0, 1, 2])
        XCTAssertEqual(ChainText.pageList("abc", count: 2), [0, 1])
        XCTAssertEqual(ChainText.pageList("3-1", count: 5), [0, 1, 2])
        XCTAssertEqual(ChainText.pageList("2,2;2", count: 5), [1])
        XCTAssertEqual(ChainText.pageList("5, 1", count: 5), [4, 0], "pages come out in the order written")
        XCTAssertEqual(ChainText.pageList("1-999999999", count: 4), [0, 1, 2, 3])
        XCTAssertEqual(ChainText.pageList("7-9", count: 3), [0, 1, 2], "pages that don't exist fall back to the whole PDF")
        XCTAssertEqual(ChainText.pageList("1\u{2013}2", count: 5), [0, 1])
        XCTAssertEqual(ChainText.pageList("1", count: 0), [])
        XCTAssertEqual(ChainText.pdfLimit(nil), 5); XCTAssertEqual(ChainText.pdfLimit("2"), 2); XCTAssertEqual(ChainText.pdfLimit("0"), 1)
    }
    func testTrimKeepsTheStartOrTheEnd() {
        var w = ChainText.trimWindow(side: "first", secs: "30", duration: 100)
        XCTAssertEqual(w.start, 0); XCTAssertEqual(w.end, 30)
        w = ChainText.trimWindow(side: "last", secs: "30", duration: 100)
        XCTAssertEqual(w.start, 70); XCTAssertEqual(w.end, 100)
        w = ChainText.trimWindow(side: "last", secs: "30", duration: 12)
        XCTAssertEqual(w.start, 0); XCTAssertEqual(w.end, 12, "a short video is kept whole")
        w = ChainText.trimWindow(side: nil, secs: nil, duration: 100)
        XCTAssertEqual(w.end, 30)
        w = ChainText.trimWindow(side: "first", secs: "0", duration: 100)
        XCTAssertEqual(w.end, 1)
        XCTAssertEqual(ChainText.turnDegrees("left"), 270); XCTAssertEqual(ChainText.turnDegrees("flip"), 180); XCTAssertEqual(ChainText.turnDegrees(nil), 90)
    }
    func testCaptionsBreakOnFullLinesAndPauses() {
        let lines = ChainText.captionLines([("Hello", 0, 0.4), ("there", 0.5, 0.9), ("everyone", 1.0, 1.6), ("Next", 5.0, 5.3)], maxChars: 12)
        XCTAssertEqual(lines.map(\.text), ["Hello there", "everyone", "Next"])
        XCTAssertEqual(lines[0].start, 0); XCTAssertEqual(lines[0].end, 1.0, accuracy: 0.001)
        XCTAssertEqual(lines[1].end, 5.0, accuracy: 0.001, "a line stays up until the next one starts")
        XCTAssertEqual(lines[2].end, 9.3, accuracy: 0.001, "but never more than 4 seconds after its last word")
        XCTAssertEqual(ChainText.captionLines([("a", 0, 0.2), ("b", 2.0, 2.2)]).count, 2, "a pause starts a new line")
        XCTAssertEqual(ChainText.captionLines([("a", 0, 0.2), (" ", 0.3, 0.4), ("b", 0.5, 0.6)]).map(\.text), ["a b"])
        XCTAssertTrue(ChainText.captionLines([]).isEmpty)
    }
    func testAWebPageBecomesItsWords() {
        let html = "<html><head><title>Big &amp; Small</title><style>p{}</style></head><body><nav>Menu</nav><article><h1>Big &amp; Small</h1><p>First\n para.</p><ul><li>One</li><li>Two</li></ul><script>x()</script></article><footer>Foot</footer></body></html>"
        XCTAssertEqual(ChainText.article(html: html), "Big & Small\nFirst para.\n\u{2022} One\n\u{2022} Two")
        XCTAssertEqual(ChainText.article(html: "<p>only</p>"), "only")
        XCTAssertEqual(ChainText.article(html: "<title>T</title><div>A<br>B</div>"), "T\nA\nB")
        XCTAssertEqual(ChainText.article(html: ""), "")
        XCTAssertEqual(ChainText.article(html: "<script>var a = 1</script>"), "")
        XCTAssertEqual(ChainText.pageLink(in: "https://example.com/x"), "https://example.com/x")
        XCTAssertNil(ChainText.pageLink(in: "no links here"))
    }
    func testLanguagesStylesGridAndLocation() {
        XCTAssertEqual(ChainText.languages.count, 19); XCTAssertEqual(Set(ChainText.languages.map(\.code)).count, 19)
        XCTAssertEqual(ChainText.languageCode("xx"), "en"); XCTAssertEqual(ChainText.languageCode("es"), "es"); XCTAssertEqual(ChainText.languageName("es"), "Spanish")
        XCTAssertEqual(ChainText.rewriteStyle("nope"), "clear"); XCTAssertEqual(ChainText.rewriteStyle("formal"), "formal")
        XCTAssertTrue(ChainText.rewriteAsk("short").contains("half")); XCTAssertTrue(ChainText.rewriteAsk("clear").contains("Reply with the rewritten text only"))
        for (n, c, r) in [(0, 0, 0), (1, 1, 1), (2, 2, 1), (3, 2, 2), (4, 2, 2), (5, 3, 2), (9, 3, 3), (10, 4, 3)] {
            XCTAssertEqual(ChainText.collageGrid(n).cols, c, "\(n)"); XCTAssertEqual(ChainText.collageGrid(n).rows, r, "\(n)")
        }
        XCTAssertEqual(ChainText.locationText(latitude: 41.87811, longitude: -87.6298, address: "Main St"), "I'm here: Main St\nhttps://maps.google.com/?q=41.87811,-87.62980")
        XCTAssertEqual(ChainText.locationText(latitude: 1, longitude: 2, address: " "), "I'm here:\nhttps://maps.google.com/?q=1.00000,2.00000")
    }
    func testASharedToolNeverCarriesAPdfPassword() throws {
        var c = chain([.pdfLock])
        c.steps[0].settings["password"] = "s3cret-word"
        XCTAssertFalse(c.shareText.contains("s3cret-word"))
        XCTAssertNil(try XCTUnwrap(Chain.imported(from: c.shareText)).steps[0].settings["password"])
    }
    func testNewStartersAreSetUpAsDescribed() throws {
        XCTAssertEqual(try XCTUnwrap(ChainTemplates.all.first { $0.id == "photo-collage" }).collage, true)
        XCTAssertEqual(try XCTUnwrap(ChainTemplates.all.first { $0.id == "pdf-join" }).combine, true)
        XCTAssertEqual(try XCTUnwrap(ChainTemplates.all.first { $0.id == "video-words" }).steps.map(\.block), [.videoAudio, .speechText])
        XCTAssertNil(chain([.cleanText]).collage, "tools saved before collages existed still load without one")
    }
    func testPlannerUnderstandsTheNewKinds() {
        func blocks(_ ask: String) -> [Block] { ChainPlanner.keywordPlan(ask)?.steps.map(\.block) ?? [] }
        XCTAssertEqual(blocks("transcribe my voice memo"), [.speechText])
        XCTAssertEqual(blocks("write out what was said in a video and find the tasks"), [.videoAudio, .speechText, .actionItems])
        XCTAssertEqual(blocks("add captions to my video"), [.videoCaptions])
        XCTAssertEqual(blocks("turn a video into a gif"), [.videoGif])
        let story = ChainPlanner.keywordPlan("keep the first 15 seconds of a video and make it vertical")
        XCTAssertEqual(story?.steps.map(\.block), [.videoTrim, .videoVertical]); XCTAssertEqual(story?.steps.first?.settings["secs"], "15")
        let join = ChainPlanner.keywordPlan("merge pdfs into one")
        XCTAssertEqual(join?.steps.map(\.block), [.pdfPages]); XCTAssertEqual(join?.combine, true)
        XCTAssertEqual(ChainPlanner.keywordPlan("shrink a pdf under 2 mb")?.steps.first?.settings["mb"], "2")
        XCTAssertEqual(blocks("shrink a pdf under 2 mb"), [.pdfShrink])
        XCTAssertEqual(blocks("lock a pdf with a password"), [.pdfLock])
        let menu = ChainPlanner.keywordPlan("translate a photo of a menu into spanish")
        XCTAssertEqual(menu?.steps.map(\.block), [.readText, .translate]); XCTAssertEqual(menu?.steps.last?.settings["to"], "es")
        XCTAssertEqual(ChainPlanner.keywordPlan("translate this text")?.steps.last?.settings["to"], "en")
        XCTAssertEqual(blocks("save a web page as a pdf"), [.pageText, .textPdf])
        XCTAssertEqual(blocks("read this text aloud"), [.readAloud])
        XCTAssertEqual(blocks("is this qr code safe"), [.readCode, .scamCheck])
        XCTAssertEqual(blocks("turn a link into a qr code"), [.makeQr], "making a code is still making a code")
        XCTAssertEqual(ChainPlanner.keywordPlan("rewrite this to be more formal")?.steps.first?.settings["style"], "formal")
        XCTAssertEqual(blocks("strip the location and make a pdf"), [.stripLocation, .photoPdf], "a photo into a PDF is still a photo tool")
    }
}

/// The new steps running for real: PDFs, text to PDF, codes, collages, and the checks for what a phone can do.
final class NewStepRunTests: XCTestCase {
    private func pdf(pages: [String]) -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { c in
            for line in pages {
                c.beginPage()
                (line as NSString).draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
    }
    private func run(_ block: Block, _ settings: [String: String] = [:], on input: ChainPayload, dryRun: Bool = false) async -> Result<ChainPayload, ChainRunner.Failure> {
        await ChainRunner.apply(ChainStep(block: block, settings: settings), to: input, dryRun: dryRun)
    }

    func testAFileKnowsItsKind() {
        XCTAssertEqual(ChainPayload.file(Data(), ext: "pdf").kind, .pdf)
        XCTAssertEqual(ChainPayload.file(Data(), ext: "PDF").kind, .pdf)
        XCTAssertEqual(ChainPayload.file(Data(), ext: "m4a").kind, .audio)
        XCTAssertEqual(ChainPayload.file(Data(), ext: "jpg").kind, .photoFile)
        XCTAssertEqual(ChainPayload.file(Data(), ext: "csv").kind, .file)
        XCTAssertEqual(ChainPayload.file(Data(), ext: "gif").kind, .file)
    }
    func testTextBecomesAPdfThatHoldsItsWords() async throws {
        let r = await run(.textPdf, on: .text("Rent agreement\nThe tenant pays on the first of each month."))
        guard case .success(.file(let d, let ext)) = r else { return XCTFail("no PDF") }
        XCTAssertEqual(ext, "pdf")
        let doc = try XCTUnwrap(PDFDocument(data: d))
        XCTAssertEqual(doc.pageCount, 1)
        XCTAssertTrue((doc.string ?? "").contains("tenant pays"))
        // Long text runs on to more pages instead of being cut off.
        let long = await run(.textPdf, on: .text(Array(repeating: "A line of words that fills the page a little at a time.", count: 400).joined(separator: "\n")))
        guard case .success(.file(let many, _)) = long else { return XCTFail("no long PDF") }
        XCTAssertGreaterThan(try XCTUnwrap(PDFDocument(data: many)).pageCount, 3)
        if case .success = await run(.textPdf, on: .text("   ")) { XCTFail("nothing to lay out") }
    }
    func testKeepSomePagesKeepsThemInTheOrderAsked() async throws {
        let three = pdf(pages: ["Page one", "Page two", "Page three"])
        let r = await run(.pdfPages, ["pages": "3, 1"], on: .file(three, ext: "pdf"))
        guard case .success(.file(let d, "pdf")) = r else { return XCTFail("no PDF") }
        let doc = try XCTUnwrap(PDFDocument(data: d))
        XCTAssertEqual(doc.pageCount, 2)
        XCTAssertTrue((doc.page(at: 0)?.string ?? "").contains("Page three"))
        let all = await run(.pdfPages, ["pages": ""], on: .file(three, ext: "pdf"))
        guard case .success(.file(let whole, _)) = all else { return XCTFail("no PDF") }
        XCTAssertEqual(PDFDocument(data: whole)?.pageCount, 3)
    }
    func testALockedPdfNeedsItsPassword() async throws {
        let r = await run(.pdfLock, ["password": "open-sesame"], on: .file(pdf(pages: ["Private"]), ext: "pdf"))
        guard case .success(.file(let d, "pdf")) = r else { return XCTFail("no PDF") }
        let doc = try XCTUnwrap(PDFDocument(data: d))
        XCTAssertTrue(doc.isLocked)
        XCTAssertTrue(doc.unlock(withPassword: "open-sesame"))
        let none = await run(.pdfLock, ["password": " "], on: .file(pdf(pages: ["Private"]), ext: "pdf"))
        guard case .failure(.invalid(let why)) = none else { return XCTFail("a lock with no password must say so") }
        XCTAssertTrue(why.contains("needs a password"))
    }
    func testPdfWordsAndShrinkNeverMakeThingsWorse() async {
        let two = pdf(pages: ["Invoice 1042", "Second page"])
        guard case .success(.text(let words)) = await run(.pdfText, on: .file(two, ext: "pdf")) else { return XCTFail("no words") }
        XCTAssertTrue(words.contains("Invoice 1042")); XCTAssertTrue(words.contains("Second page"))
        guard case .success(.file(let small, "pdf")) = await run(.pdfShrink, ["mb": "1"], on: .file(two, ext: "pdf")) else { return XCTFail("no PDF") }
        XCTAssertLessThanOrEqual(small.count, two.count)
        guard case .failure(.invalid(let why)) = await run(.pdfShrink, on: .file(Data("not a pdf".utf8), ext: "pdf")) else { return XCTFail("junk must be refused") }
        XCTAssertTrue(why.contains("couldn't open that PDF"))
    }
    func testATextToolCanEndAsALockedPdf() async throws {
        let c = Chain(id: "x", name: "x", steps: [ChainStep(block: .textPdf), ChainStep(block: .pdfLock, settings: ["password": "pw"])])
        guard case .success(.file(let d, "pdf")) = await ChainRunner.run(c, input: .text("Minutes of the meeting.")) else { return XCTFail("chain failed") }
        XCTAssertEqual(PDFDocument(data: d)?.isLocked, true)
    }
    func testReadThePageNeedsALinkAndPreviewsWithoutTheNetwork() async {
        guard case .success(.text(let sample)) = await run(.pageText, on: .text("see https://example.com/a"), dryRun: true) else { return XCTFail("a preview never fetches") }
        XCTAssertEqual(sample, ChainExtras.samplePage)
        guard case .failure(.invalid(let why)) = await run(.pageText, on: .text("no link in here"), dryRun: true) else { return XCTFail("no link must be said plainly") }
        XCTAssertTrue(why.contains("needs a web link"))
    }
    func testACodeIsReadBackWhenThePhoneCanSeeIt() async throws {
        let code = try XCTUnwrap(ChainText.qr("https://example.com/menu"))
        // The simulator's code reader is not dependable, so only a wrong answer fails here, never a missed one.
        if let read = ChainExtras.readCode(code) { XCTAssertEqual(read, "https://example.com/menu") }
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { c in UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 300)) }
        guard case .failure(.invalid(let why)) = await run(.readCode, on: .image(blank)) else { return XCTFail("a picture with no code must say so") }
        XCTAssertTrue(why.contains("didn't find a code"))
    }
    func testPhotosBecomeOneCollage() throws {
        func tile(_ c: UIColor) -> UIImage {
            let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: f).image { ctx in c.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300)) }
        }
        guard case .image(let three)? = ChainCombine.onePicture([.image(tile(.red)), .image(tile(.green)), .file(tile(.blue).jpegData(compressionQuality: 0.8)!, ext: "jpg")]) else { return XCTFail("no collage") }
        XCTAssertEqual(three.size.width, 2 * 900 + 3 * 12); XCTAssertEqual(three.size.height, 2 * 900 + 3 * 12)
        guard case .image(let two)? = ChainCombine.onePicture([.image(tile(.red)), .image(tile(.green))]) else { return XCTFail("no collage") }
        XCTAssertEqual(two.size.width, 2 * 900 + 3 * 12); XCTAssertEqual(two.size.height, 900 + 2 * 12)
        XCTAssertNil(ChainCombine.onePicture([.image(tile(.red)), .text("words")]))
        XCTAssertNil(ChainCombine.onePicture([]))
    }
    func testAStepThisPhoneCannotRunSaysSoInsteadOfFailing() async {
        // Steps that need nothing special are always there.
        for b in [Block.readCode, .pageText, .textPdf, .pdfShrink, .pdfLock, .pdfPages, .pdfText, .translate, .readAloud, .videoTrim, .videoGif, .videoRotate, .videoVertical] {
            XCTAssertNil(b.unavailable, b.rawValue)
        }
        XCTAssertNil(Chain(id: "a", name: "a", steps: [ChainStep(block: .cleanText)]).unavailable)
        // Whatever this device supports, a missing step is reported in words and the tool names it.
        for b in [Block.speechText, .videoCaptions, .rewrite] {
            let c = Chain(id: "a", name: "a", steps: [ChainStep(block: b)])
            if let why = b.unavailable {
                XCTAssertFalse(why.isEmpty)
                XCTAssertTrue((c.unavailable ?? "").hasPrefix("\(b.title) isn't available on this phone."))
                let input: ChainPayload = b.takes == .text ? .text("hello") : b.takes == .video ? .video(URL(fileURLWithPath: "/nope.mp4")) : .file(Data(), ext: "m4a")
                guard case .failure(.invalid(let said)) = await ChainRunner.apply(ChainStep(block: b), to: input) else { return XCTFail("\(b.rawValue) should stop with a reason") }
                XCTAssertTrue(said.contains("isn't available on this phone"))
                XCTAssertFalse(ChainStore.offers(for: b.takes, mine: [c], last: nil).contains { $0.id == "a" }, "a tool this phone can't run isn't offered in the share sheet")
            } else {
                XCTAssertNil(c.unavailable)
            }
        }
    }
    func testTallCropKeepsTheMiddleAtNineBySixteen() {
        let wide = ChainMedia.tallCrop(CGSize(width: 1920, height: 1080))
        XCTAssertEqual(wide.width, 606); XCTAssertEqual(wide.height, 1080); XCTAssertEqual(wide.minX, 657); XCTAssertEqual(wide.minY, 0)
        let tall = ChainMedia.tallCrop(CGSize(width: 1080, height: 1920))
        XCTAssertEqual(tall, CGRect(x: 0, y: 0, width: 1080, height: 1920), "a video that is already tall is left as it is")
        let square = ChainMedia.tallCrop(CGSize(width: 1000, height: 1000))
        XCTAssertEqual(square.width, 562); XCTAssertEqual(square.height, 1000)
    }
    func testACaptionIsDrawnOnlyWhileItIsDue() throws {
        let art = CaptionArt(lines: [("Hello there", 1.0, 3.0)])
        let frame = CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 360))
        XCTAssertEqual(art.draw(over: frame, at: 0.5).extent, frame.extent)
        XCTAssertEqual(art.draw(over: frame, at: 2.0).extent, frame.extent, "the caption sits inside the frame")
        let plate = try XCTUnwrap(CaptionArt.picture("Hello there", in: frame.extent.size))
        XCTAssertLessThan(plate.extent.width, 640); XCTAssertGreaterThan(plate.extent.height, 10)
    }
}

/// "Describe it" reading what people actually type: misspelt, cut short, or only half said.
final class SmartDescribeTests: XCTestCase {
    private func blocks(_ ask: String) -> [Block] { ChainPlanner.keywordPlan(ask)?.steps.map(\.block) ?? [] }

    func testMisspeltWordsAreReadAsMeant() {
        XCTAssertEqual(PlannerWords.tidy("Shrnk my foto and remve the loction"), "shrink my photo and remove the location")
        XCTAssertEqual(PlannerWords.tidy("vidoe"), "video", "two letters swapped is one slip")
        XCTAssertEqual(PlannerWords.tidy("comprssing a recipt"), "compress a receipt")
        XCTAssertEqual(PlannerWords.tidy("trnslate to spansh"), "translate to spanish")
        XCTAssertEqual(PlannerWords.tidy("watermak pasword sumarize"), "watermark password summarize")
    }
    func testWhatIsAlreadyRightIsLeftAlone() {
        XCTAssertEqual(PlannerWords.tidy("under 50 kb, 9:16 & to-do, tl;dr"), "under 50 kb, 9:16 & to-do, tl;dr")
        XCTAssertEqual(PlannerWords.tidy("the store phone price"), "the store phone price", "real words near a known one are not changed")
        XCTAssertEqual(PlannerWords.tidy("make it clear and formal"), "make it clear and formal")
        XCTAssertEqual(PlannerWords.tidy("xyzzy qwrtp"), "xyzzy qwrtp", "words it doesn't know stay as typed")
        XCTAssertEqual(PlannerWords.tidy(""), "")
        XCTAssertEqual(PlannerWords.distance("photo", "phto", limit: 2), 1); XCTAssertEqual(PlannerWords.distance("video", "vidoe", limit: 2), 1)
        XCTAssertEqual(PlannerWords.distance("photo", "banana", limit: 2), 3, "anything further than the limit is just 'too far'")
    }
    func testTyposStillBuildTheRightTool() {
        XCTAssertEqual(blocks("shrnk my foto and remve the loction"), [.stripLocation, .shrinkImage])
        XCTAssertEqual(blocks("compres my vidoe for watsapp"), [.videoShrink])
        XCTAssertEqual(ChainPlanner.keywordPlan("compres my vidoe for watsapp")?.steps.first?.settings["mb"], "16")
        XCTAssertEqual(blocks("trnslate a pic of a menu to spansh"), [.readText, .translate])
        XCTAssertEqual(ChainPlanner.keywordPlan("trnslate a pic of a menu to spansh")?.steps.last?.settings["to"], "es")
        XCTAssertEqual(blocks("voice memmo to notes"), [.speechText])
        XCTAssertEqual(blocks("sumarize this artcle"), [.pageText, .summarize])
        XCTAssertEqual(blocks("is this mesage a scm"), [.scamCheck], "'scm' is too short to correct, but the rest still points at the right starter")
        XCTAssertEqual(blocks("is this mesage a scam"), [.scamCheck])
    }
    func testHalfARequestStillGetsTheWholeJob() {
        // Posting a photo without personal details: cover them, drop the location, make it small enough to post.
        XCTAssertEqual(blocks("I want to post a photo online stripping all the personal data"), [.hideSensitive, .stripLocation, .shrinkImage])
        XCTAssertEqual(blocks("remove personal info from my picture"), [.hideSensitive, .stripLocation])
        XCTAssertEqual(blocks("post this pic on instagram"), [.stripLocation, .shrinkImage])
        XCTAssertEqual(blocks("my photo"), [.stripLocation, .shrinkImage], "only the kind of thing was said, so it gets the most useful tool for it")
        XCTAssertEqual(blocks("some notes"), [.cleanText])
        XCTAssertEqual(blocks("collage"), [.stripLocation]); XCTAssertEqual(ChainPlanner.keywordPlan("collage")?.collage, true)
        XCTAssertEqual(ChainPlanner.keywordPlan("colage")?.name, "Photos into one collage", "one word, misspelt, still finds its starter")
        XCTAssertEqual(blocks("pasport"), [.passportPhoto])
        XCTAssertNil(ChainPlanner.keywordPlan("make me a sandwich"))
        XCTAssertNil(ChainPlanner.keywordPlan("   "))
    }
    func testItSaysWhenItIsOnlyAGuess() {
        XCTAssertEqual(ChainPlanner.guess("shrink a photo under 1 mb")?.sure, true)
        XCTAssertEqual(ChainPlanner.guess("my photo")?.sure, false)
        XCTAssertEqual(ChainPlanner.guess("collage")?.sure, false)
        XCTAssertNotEqual(ChainPlanner.guess("collage")?.chain.id, "photo-collage", "a guessed starter is a copy with its own id")
    }
    func testTheEndingIsReadFromTheRequest() {
        XCTAssertEqual(ChainPlanner.keywordPlan("shrink a photo and email it")?.finish?.kind, .mail)
        XCTAssertEqual(ChainPlanner.keywordPlan("scan a receipt and text it to my accountant")?.finish?.kind, .message)
        XCTAssertNil(ChainPlanner.keywordPlan("find the email address in some text")?.finish)
        XCTAssertNil(ChainPlanner.keywordPlan("shrink a photo under 1 mb")?.finish)
    }
    func testToolsGetNamesPeopleCanRead() {
        XCTAssertEqual(ChainPlanner.keywordPlan("shrink video for whatsapp")?.name, "Shrink video for whatsapp", "a short request is its own name")
        let long = ChainPlanner.keywordPlan("I want to post a photo online stripping all the personal data")
        XCTAssertEqual(long?.name, "Privacy share shield", "a long request is named for what the tool does")
        let c = Chain(id: "x", name: "My tool", steps: [ChainStep(block: .readText), ChainStep(block: .translate), ChainStep(block: .readAloud)])
        XCTAssertEqual(ChainText.autoName(c), "Read text + 2 more")
        XCTAssertEqual(ChainText.autoName(Chain(id: "x", name: "", steps: [ChainStep(block: .enhance), ChainStep(block: .watermark)])), "Enhance + Add a watermark")
        XCTAssertEqual(ChainText.autoName(Chain(id: "x", name: "", steps: [ChainStep(block: .calendarEvent)])), "Make a calendar event")
        XCTAssertEqual(ChainText.autoName(Chain(id: "x", name: "", steps: [])), "My tool")
        XCTAssertEqual(ChainText.savedName(c), "Read text + 2 more", "a tool left as My tool is named for its steps when saved")
        var named = c; named.name = "  Menu helper "
        XCTAssertEqual(ChainText.savedName(named), "Menu helper")
    }
}

/// "Start with what you have": the thing is sorted by what it is, and every kind has a tool waiting.
final class GivenTests: XCTestCase {
    func testPastedWordsAreTextOrALink() {
        XCTAssertEqual(Given.from(text: "  call me at 5  ")?.label, "Some text")
        XCTAssertEqual(Given.from(text: "https://example.com/page")?.label, "A link")
        XCTAssertNil(Given.from(text: "   "))
        if case .text(let t)? = Given.from(text: " hello ")?.payload { XCTAssertEqual(t, "hello") } else { XCTFail("text expected") }
    }
    func testAFileIsSortedByItsName() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("given-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func file(_ name: String, _ data: Data) throws -> URL { let u = dir.appendingPathComponent(name); try data.write(to: u); return u }
        XCTAssertEqual(Given.from(file: try file("a.pdf", Data("%PDF".utf8)))?.payload.kind, .pdf)
        XCTAssertEqual(Given.from(file: try file("memo.m4a", Data([1, 2, 3])))?.payload.kind, .audio)
        XCTAssertEqual(Given.from(file: try file("clip.mov", Data([1, 2, 3])))?.payload.kind, .video)
        XCTAssertEqual(Given.from(file: try file("note.txt", Data("hello there".utf8)))?.payload.kind, .text)
        XCTAssertNil(Given.from(file: try file("archive.zip", Data([1, 2, 3]))), "a kind of file no tool takes is turned away, not guessed at")
        XCTAssertNil(Given.from(file: try file("empty.txt", Data())))
    }
    func testEveryKindHasAToolWaiting() {
        for k in [ChainKind.image, .text, .video, .pdf] { XCTAssertFalse(ChainStore.offers(for: k, mine: [], last: nil).isEmpty, k.rawValue) }
    }
}

final class FunStepTests: XCTestCase {
    private func chain(_ blocks: [Block]) -> Chain { Chain(id: "t", name: "t", steps: blocks.map { ChainStep(block: $0) }) }
    private func planned(_ ask: String) -> [Block] { ChainPlanner.keywordPlan(ask)?.steps.map(\.block) ?? [] }

    func testFunStepsFitWhereTheyShould() {
        for b in [Block.sticker, .emojiFaces, .meme, .emojiMosaic] { XCTAssertEqual(b.takes, .image, b.rawValue); XCTAssertEqual(b.goal, "Just for fun") }
        for b in [Block.videoSpeed, .videoLoop] { XCTAssertEqual(b.takes, .video, b.rawValue); XCTAssertEqual(b.goal, "Just for fun") }
        XCTAssertTrue(Block.goalOrder.contains("Just for fun"))
        XCTAssertNil(chain([.emojiFaces, .meme, .stripLocation]).problem(starting: .image))
        XCTAssertNil(chain([.sticker, .shrinkImage]).problem(starting: .image))
        XCTAssertNil(chain([.videoTrim, .videoSpeed, .videoShrink]).problem(starting: .video))
        XCTAssertNotNil(chain([.videoLoop, .videoShrink]).problem(starting: .video), "a boomerang is a finished GIF, not a video")
        XCTAssertNotNil(chain([.meme]).problem(starting: .text))
    }
    func testFunHelpersDoWhatTheySay() {
        XCTAssertEqual(ChainText.faceEmoji(nil), ChainText.faceEmojis[0]); XCTAssertEqual(ChainText.faceEmoji("x"), ChainText.faceEmojis[0]); XCTAssertEqual(ChainText.faceEmoji("🤖"), "🤖")
        XCTAssertEqual(ChainText.memeText("  when it\nworks   first time "), "WHEN IT WORKS FIRST TIME")
        XCTAssertEqual(ChainText.memeText("   "), ""); XCTAssertEqual(ChainText.memeText(String(repeating: "ab ", count: 100)).count, 120)
        XCTAssertEqual(ChainText.speedRate("slow"), 0.5); XCTAssertEqual(ChainText.speedRate("fast"), 2); XCTAssertEqual(ChainText.speedRate("faster"), 4); XCTAssertEqual(ChainText.speedRate(nil), 0.5)
        XCTAssertEqual(ChainText.loopOrder(4, style: "boomerang"), [0, 1, 2, 3, 2, 1]); XCTAssertEqual(ChainText.loopOrder(4, style: nil), [0, 1, 2, 3, 2, 1])
        XCTAssertEqual(ChainText.loopOrder(4, style: "reverse"), [3, 2, 1, 0])
        XCTAssertEqual(ChainText.loopOrder(2, style: "boomerang"), [0, 1]); XCTAssertEqual(ChainText.loopOrder(1, style: "boomerang"), [0]); XCTAssertEqual(ChainText.loopOrder(0, style: "reverse"), [])
        XCTAssertTrue(ChainText.mosaicGrid(width: 4000, height: 3000) == (56, 42)); XCTAssertTrue(ChainText.mosaicGrid(width: 3000, height: 4000) == (42, 56))
        XCTAssertTrue(ChainText.mosaicGrid(width: 5000, height: 10) == (56, 1)); XCTAssertTrue(ChainText.mosaicGrid(width: 0, height: 10) == (0, 0))
        let palette: [(r: Int, g: Int, b: Int)] = [(255, 0, 0), (0, 255, 0), (250, 250, 250)]
        XCTAssertEqual(ChainText.nearestColor(r: 200, g: 30, b: 20, in: palette), 0); XCTAssertEqual(ChainText.nearestColor(r: 255, g: 255, b: 255, in: palette), 2)
        XCTAssertEqual(ChainText.nearestColor(r: 1, g: 2, b: 3, in: []), -1)
        XCTAssertEqual(Set(ChainText.mosaicEmojis).count, ChainText.mosaicEmojis.count); XCTAssertGreaterThanOrEqual(ChainText.mosaicEmojis.count, 48)
    }
    func testDescribeItUnderstandsTheFunRequests() {
        XCTAssertEqual(planned("make a meme"), [.meme])
        XCTAssertEqual(planned("turn my dog into a sticker"), [.sticker]); XCTAssertEqual(planned("whatsapp stikcer of my cat"), [.sticker])
        XCTAssertEqual(planned("remove the background"), [.cutout])
        XCTAssertEqual(planned("put an emoji on my kids faces"), [.emojiFaces]); XCTAssertEqual(planned("hide faces with emojis"), [.emojiFaces])
        XCTAssertEqual(planned("emoji mosaic of my selfie"), [.emojiMosaic]); XCTAssertEqual(planned("photo made of emojis"), [.emojiMosaic])
        XCTAssertEqual(planned("boomerang"), [.videoLoop]); XCTAssertEqual(ChainPlanner.keywordPlan("bomerang of my video")?.steps.first?.settings["style"], "boomerang")
        XCTAssertEqual(ChainPlanner.keywordPlan("play my video backwards")?.steps.first?.settings["style"], "reverse")
        XCTAssertEqual(ChainPlanner.keywordPlan("slow motion video")?.steps.first?.settings["speed"], "slow"); XCTAssertEqual(planned("slow mo"), [.videoSpeed])
        XCTAssertEqual(ChainPlanner.keywordPlan("speed up my video")?.steps.first?.settings["speed"], "fast"); XCTAssertEqual(ChainPlanner.keywordPlan("make a timelapse")?.steps.first?.settings["speed"], "faster")
        let gif = ChainPlanner.keywordPlan("make a gif from my photos")
        XCTAssertEqual(gif?.gif, true); XCTAssertEqual(gif?.steps.first?.block.takes, .image)
        XCTAssertEqual(planned("turn my video into a gif"), [.videoGif]); XCTAssertNil(ChainPlanner.keywordPlan("turn my video into a gif")?.gif)
        XCTAssertEqual(planned("live photo to a gif"), [.videoGif])
        XCTAssertEqual(planned("shrink video for whatsapp"), [.videoShrink])
        XCTAssertFalse(planned("what I spend on a faster phone").contains(.videoSpeed))
    }
    func testTheGifOptionTravelsWithTheTool() throws {
        let t = try XCTUnwrap(ChainTemplates.all.first { $0.id == "photos-gif" })
        XCTAssertEqual(t.gif, true); XCTAssertNil(t.collage)
        XCTAssertEqual(Chain.imported(from: t.shareText)?.gif, true)
        XCTAssertNil(Chain.imported(from: chain([.cleanText]).shareText)?.gif)
        XCTAssertEqual(ChainText.autoName(chain([.sticker])), "Photo to a sticker")
    }

    // The drawing itself, on a real phone.
    private func picture(_ size: CGSize = CGSize(width: 400, height: 300), _ color: UIColor = .systemBlue) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in color.setFill(); c.fill(CGRect(origin: .zero, size: size)) }
    }
    func testMemeTextKeepsThePhotoSizeAndNeedsWords() async {
        let src = picture()
        let made = await ChainRunner.apply(ChainStep(block: .meme, settings: ["top": "one does not simply", "bottom": "ship without testing"]), to: .image(src))
        guard case .success(.image(let out)) = made else { return XCTFail("no meme") }
        XCTAssertEqual(out.size, src.size)
        XCTAssertNotEqual(out.pngData(), src.pngData())
        let empty = await ChainRunner.apply(ChainStep(block: .meme, settings: ["top": " ", "bottom": ""]), to: .image(src))
        guard case .failure(.invalid(let why)) = empty else { return XCTFail("empty words should be refused") }
        XCTAssertTrue(why.contains("needs some words"))
    }
    func testEmojiMosaicIsBuiltFromTheGrid() async {
        let made = await ChainRunner.apply(ChainStep(block: .emojiMosaic), to: .image(picture(CGSize(width: 400, height: 300))))
        guard case .success(.image(let out)) = made else { return XCTFail("no mosaic") }
        XCTAssertEqual(out.size, CGSize(width: 56 * 28, height: 42 * 28))
    }
    func testEmojiFacesSaysSoWhenThereIsNoFace() async {
        let made = await ChainRunner.apply(ChainStep(block: .emojiFaces), to: .image(picture()))
        guard case .failure(.invalid(let why)) = made else { return XCTFail("a plain picture has no face") }
        XCTAssertTrue(why.contains("didn't find a face"))
    }
    func testStickerTrimsToTheSubjectAndAddsAnEdge() throws {
        // A red disc on a see-through square: the sticker is the disc plus its white edge, nothing more.
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let cut = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: fmt).image { c in
            UIColor.red.setFill(); c.cgContext.fillEllipse(in: CGRect(x: 150, y: 100, width: 100, height: 100))
        }
        let box = try XCTUnwrap(ChainFun.solidBounds(try XCTUnwrap(cut.cgImage)))
        XCTAssertEqual(box.midX, 200, accuracy: 4); XCTAssertEqual(box.midY, 150, accuracy: 4); XCTAssertEqual(box.width, 100, accuracy: 8)
        let made = try XCTUnwrap(ChainFun.sticker(cut))
        XCTAssertEqual(made.size.width, made.size.height, accuracy: 2)
        XCTAssertGreaterThan(made.size.width, 200)       // enlarged to a useful sticker size, with room for the edge
        XCTAssertNil(ChainFun.sticker(UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50), format: fmt).image { _ in }))
    }
    func testPhotosBecomeOneGif() {
        let made = ChainCombine.oneGif([.image(picture()), .image(picture(CGSize(width: 300, height: 500), .systemRed))])
        guard case .file(let d, let ext)? = made else { return XCTFail("no GIF") }
        XCTAssertEqual(ext, "gif"); XCTAssertEqual(String(data: d.prefix(3), encoding: .ascii), "GIF")
        XCTAssertNil(ChainCombine.oneGif([.text("words")])); XCTAssertNil(ChainCombine.oneGif([]))
    }
}

final class NewestStepTests: XCTestCase {
    private func chain(_ blocks: [Block]) -> Chain { Chain(id: "t", name: "t", steps: blocks.map { ChainStep(block: $0) }) }
    private func planned(_ ask: String) -> [Block] { ChainPlanner.keywordPlan(ask)?.steps.map(\.block) ?? [] }

    func testPicturesAreRedrawnInEachStyle() {
        // A 6 by 4 picture: left half black, right half white.
        let w = 6, h = 4
        let px = (0..<(w * h)).map { $0 % w < 3 ? 0x000000 : 0xFFFFFF }
        XCTAssertEqual(Set(PixelArt.gray(px)), [0, 255])
        let flat = [Int](repeating: 100, count: w * h)
        XCTAssertTrue(PixelArt.blur(flat, width: w, height: h, radius: 2).allSatisfy { $0 == 100 })
        XCTAssertEqual(PixelArt.blur(flat, width: w, height: h, radius: 0), flat)
        let soft = PixelArt.blur(PixelArt.gray(px), width: w, height: h, radius: 1)
        XCTAssertTrue((1...254).contains(soft[2])); XCTAssertEqual(soft[0], 0); XCTAssertEqual(soft[5], 255)
        let noir = PixelArt.apply(px, width: w, height: h, style: "noir"); XCTAssertEqual(noir[0], 0x000000); XCTAssertEqual(noir[5], 0xFFFFFF)
        let pop = PixelArt.apply(px, width: w, height: h, style: "pop"); XCTAssertEqual(Set(pop).count, 2); XCTAssertEqual(pop[0], 0x1B1464); XCTAssertEqual(pop[5], 0xFFF8E7)
        let wall = [Int](repeating: 0x808080, count: w * h)
        let sketch = PixelArt.apply(wall, width: w, height: h, style: "sketch")
        XCTAssertTrue(sketch.allSatisfy { $0 == 0xFFFFFF }, "an even grey wall is blank paper")
        XCTAssertEqual(PixelArt.apply(wall, width: w, height: h, style: "nonsense"), sketch)
        XCTAssertTrue(PixelArt.apply([Int](repeating: 0x2060E0, count: w * h), width: w, height: h, style: "comic").allSatisfy { $0 == 0x4080FF })
        XCTAssertEqual(PixelArt.apply(px, width: 5, height: 5, style: "noir"), px)
        XCTAssertEqual(PixelArt.style(nil), "sketch"); XCTAssertEqual(PixelArt.style("comic"), "comic"); XCTAssertEqual(PixelArt.style("x"), "sketch")
    }
    func testVoicesAndWavFiles() {
        XCTAssertEqual(ChainText.voiceRate("chipmunk"), 1.5); XCTAssertEqual(ChainText.voiceRate("deep"), 0.75); XCTAssertEqual(ChainText.voiceRate(nil), 1.5)
        let head = ChainText.wavHeader(sampleRate: 44100, channels: 1, dataBytes: 1000)
        XCTAssertEqual(head.count, 44)
        XCTAssertEqual(String(bytes: head[0..<4], encoding: .ascii), "RIFF"); XCTAssertEqual(String(bytes: head[8..<16], encoding: .ascii), "WAVEfmt "); XCTAssertEqual(String(bytes: head[36..<40], encoding: .ascii), "data")
        func int(_ at: Int) -> Int { Int(head[at]) | Int(head[at + 1]) << 8 | Int(head[at + 2]) << 16 | Int(head[at + 3]) << 24 }
        XCTAssertEqual(int(4), 1036); XCTAssertEqual(int(24), 44100); XCTAssertEqual(int(28), 88200); XCTAssertEqual(int(40), 1000)
        XCTAssertEqual(Block.voiceChange.takes, .audio); XCTAssertEqual(Block.voiceChange.gives, .audio)
        XCTAssertNil(chain([.videoAudio, .voiceChange]).problem(starting: .video)); XCTAssertNil(chain([.voiceChange, .speechText]).problem(starting: .audio))
    }
    func testAToolTravelsAsALink() throws {
        var tool = Chain(id: "x", name: "Menu helper é", steps: [ChainStep(block: .readText), ChainStep(block: .translate, settings: ["to": "es"])])
        tool.finish = ChainFinish(kind: .mail, to: "me@example.com")
        let link = try XCTUnwrap(ToolLink.link(for: tool))
        XCTAssertTrue(link.hasPrefix(ToolLink.page + "#")); XCTAssertFalse(link.contains("example.com"))
        let packed = String(link[link.index(after: try XCTUnwrap(link.firstIndex(of: "#")))...])
        XCTAssertFalse(packed.contains("="))
        let back = ToolLink.chain(from: link)
        XCTAssertEqual(back?.name, "Menu helper é"); XCTAssertEqual(back?.steps, tool.steps); XCTAssertEqual(back?.finish?.to, "")
        XCTAssertEqual(ToolLink.chain(from: "tenzy://import?d=" + packed)?.steps, tool.steps)
        XCTAssertEqual(ToolLink.chain(from: tool.shareText)?.steps, tool.steps)
        XCTAssertNil(ToolLink.chain(from: "https://example.com/t.html#abc")); XCTAssertNil(ToolLink.chain(from: ToolLink.page + "#not-a-tool")); XCTAssertNil(ToolLink.chain(from: ""))
    }
    func testDescribeItUnderstandsTheNewestRequests() {
        XCTAssertEqual(ChainPlanner.keywordPlan("pencil sketch of my photo")?.steps.first?.settings["style"], "sketch")
        XCTAssertEqual(ChainPlanner.keywordPlan("turn me into a cartoon")?.steps.first?.settings["style"], "comic")
        XCTAssertEqual(ChainPlanner.keywordPlan("pop art selfie")?.steps.first?.settings["style"], "pop")
        XCTAssertEqual(ChainPlanner.keywordPlan("make it black and white")?.steps.first?.settings["style"], "noir")
        XCTAssertEqual(planned("chipmunk voice"), [.voiceChange]); XCTAssertEqual(ChainPlanner.keywordPlan("give me a deep voice")?.steps.first?.settings["voice"], "deep")
        XCTAssertEqual(planned("funny voice from my video"), [.videoAudio, .voiceChange])
        XCTAssertEqual(ChainPlanner.keywordPlan("before and after photo of my kitchen")?.versus, true); XCTAssertNil(ChainPlanner.keywordPlan("shrink a photo")?.versus)
        let starter = ChainTemplates.all.first { $0.id == "before-after" }
        XCTAssertEqual(starter?.versus, true); XCTAssertEqual(Chain.imported(from: starter?.shareText ?? "")?.versus, true)
        XCTAssertEqual(planned("which is the cheapest per unit").last, .priceCompare)
    }
}

final class NewestDrawingTests: XCTestCase {
    private func picture(_ size: CGSize, _ color: UIColor) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in color.setFill(); c.fill(CGRect(origin: .zero, size: size)) }
    }
    func testArtKeepsTheShapeAndShrinksBigPhotos() async {
        let small = await ChainRunner.apply(ChainStep(block: .artFilter, settings: ["style": "comic"]), to: .image(picture(CGSize(width: 400, height: 300), .systemBlue)))
        guard case .success(.image(let out)) = small else { return XCTFail("no picture") }
        XCTAssertEqual(out.size, CGSize(width: 400, height: 300))
        let big = ChainFun.art(picture(CGSize(width: 3200, height: 1600), .systemRed), style: "sketch")
        XCTAssertEqual(big?.size, CGSize(width: 1600, height: 800))
    }
    func testBeforeAndAfterNeedsTwoPictures() {
        let a = picture(CGSize(width: 300, height: 400), .systemGreen), b = picture(CGSize(width: 800, height: 300), .systemOrange)
        guard case .image(let out)? = ChainCombine.beforeAfter([.image(a), .image(b)]) else { return XCTFail("no picture") }
        XCTAssertEqual(out.size, CGSize(width: 900 * 2 + 36, height: 1200 + 24))
        XCTAssertNil(ChainCombine.beforeAfter([.image(a)])); XCTAssertNil(ChainCombine.beforeAfter([.image(a), .text("words")]))
    }
    func testAChangedVoiceIsAWavAtTheNewSpeed() throws {
        // One second of a plain tone, written as a .wav, then played as a chipmunk.
        let rate = 16000
        var pcm = [UInt8]()
        for i in 0..<rate { let v = Int16(sin(Double(i) * 2 * .pi * 440 / Double(rate)) * 12000); pcm.append(UInt8(truncatingIfNeeded: v)); pcm.append(UInt8(truncatingIfNeeded: v >> 8)) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try (Data(ChainText.wavHeader(sampleRate: rate, channels: 1, dataBytes: pcm.count)) + Data(pcm)).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let made = try XCTUnwrap(ChainMedia.revoice(url, rate: 1.5))
        XCTAssertEqual(String(data: made.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(Int(made[24]) | Int(made[25]) << 8 | Int(made[26]) << 16, 24000)
        XCTAssertLessThan(abs(made.count - (44 + rate * 2)), 64)
        XCTAssertNil(ChainMedia.revoice(FileManager.default.temporaryDirectory.appendingPathComponent("missing.wav"), rate: 1.5))
    }
    func testOnlyTheNewestResultsAreKept() {
        let items = (0..<25).map { HistoryItem(id: "\($0)", tool: "T", when: Date(timeIntervalSince1970: Double($0)), text: "x") }
        let kept = RunHistory.kept(items)
        XCTAssertEqual(kept.count, 20); XCTAssertEqual(kept.first?.id, "24"); XCTAssertEqual(kept.last?.id, "5")
        XCTAssertEqual(RunHistory.kept(items, limit: 0), [])
    }
}

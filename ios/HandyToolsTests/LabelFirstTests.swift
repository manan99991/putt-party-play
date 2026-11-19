import XCTest
@testable import HandyTools

final class LabelFirstTests: XCTestCase {
    private let box = """
    PAIN RELIEF
    Ibuprofen 200 mg
    24 Tablets
    Directions:
    Adults and children over 12: take 1 tablet every 4 to 6 hours
    Do not exceed 6 tablets in 24 hours
    Warning: keep out of reach of children
    Contains lactose
    EXP 08/2027
    """

    func testALabelIsReadImportantPartsFirstWordForWord() {
        XCTAssertTrue(LabelFirst.isLabel(box))
        let p = LabelFirst.parts(box)
        XCTAssertEqual(p.map(\.title), ["Directions", "Warnings", "Expiry", "Contains"])
        XCTAssertTrue(p[0].lines.contains("Adults and children over 12: take 1 tablet every 4 to 6 hours"), "the line under the heading comes with it")
        XCTAssertTrue(p[1].lines.contains("Do not exceed 6 tablets in 24 hours"))
        XCTAssertEqual(p[2].lines, ["EXP 08/2027"])
        XCTAssertFalse(LabelFirst.isLabel("Dear Sam, thanks for the lovely dinner on Friday."))
    }
}

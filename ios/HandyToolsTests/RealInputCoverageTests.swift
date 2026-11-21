import XCTest
@testable import HandyTools

/// The real-input test must run every ready-made flow: a flow added to ChainTemplates.all without being added to
/// RealInputTests.flows fails here, so nothing new ships untried on a real file.
final class RealInputCoverageTests: XCTestCase {
    func testRealInputTestListsEveryReadyMadeFlow() throws {
        let here = URL(fileURLWithPath: #filePath)
        let ui = here.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("HandyToolsUITests/RealInputTests.swift")
        let src = try String(contentsOf: ui, encoding: .utf8)
        let missing = ChainTemplates.all.map(\.id).filter { !src.contains("\"\($0)\"") }
        XCTAssertTrue(missing.isEmpty, "Add to RealInputTests.flows: \(missing.joined(separator: ", "))")
    }
}

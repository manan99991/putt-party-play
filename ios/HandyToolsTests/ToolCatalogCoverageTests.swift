import XCTest
@testable import HandyTools

/// The smoke test must open every tool in the catalog: a tool added to TOOLS without being added to
/// ToolSmokeTests.toolIDs fails here (40 of 65 were missing until 21 Nov).
final class ToolCatalogCoverageTests: XCTestCase {
    @MainActor func testSmokeTestOpensEveryTool() throws {
        let here = URL(fileURLWithPath: #filePath)
        let ui = here.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("HandyToolsUITests/ToolSmokeTests.swift")
        let src = try String(contentsOf: ui, encoding: .utf8)
        let missing = TOOLS.map(\.id).filter { !src.contains("\"\($0)\"") }
        XCTAssertTrue(missing.isEmpty, "Add to ToolSmokeTests.toolIDs: \(missing.joined(separator: ", "))")
    }
}

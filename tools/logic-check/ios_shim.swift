import Foundation
class XCTestCase { required init() {} }
var failures: [String] = []
var passed = 0
var current = ""
var failedNow = false
func note(_ m: String, _ line: UInt) { failures.append("\(current) line \(line): \(m)"); failedNow = true }
struct Unwrap: Error {}
func run(_ name: String, _ body: () throws -> Void) {
    current = name; failedNow = false
    do { try body() } catch { note("threw \(error)", 0) }
    if !failedNow { passed += 1 }
}
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ m: String = "", line: UInt = #line) {
    guard let x = try? a(), let y = try? b() else { return note("threw", line) }
    if x != y { note("expected <\(y)> got <\(x)> \(m)", line) }
}
func XCTAssertEqual<T: FloatingPoint>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, accuracy: T, line: UInt = #line) {
    guard let x = try? a(), let y = try? b() else { return note("threw", line) }
    if abs(x - y) > accuracy { note("expected <\(y)> got <\(x)>", line) }
}
func XCTAssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ m: String = "", line: UInt = #line) {
    guard let x = try? a(), let y = try? b() else { return note("threw", line) }
    if x == y { note("expected different, both <\(x)>", line) }
}
func XCTAssertTrue(_ a: @autoclosure () throws -> Bool, _ m: String = "", line: UInt = #line) { if (try? a()) != true { note("expected true \(m)", line) } }
func XCTAssertFalse(_ a: @autoclosure () throws -> Bool, _ m: String = "", line: UInt = #line) { if (try? a()) != false { note("expected false \(m)", line) } }
func XCTAssertNil<T>(_ a: @autoclosure () throws -> T?, _ m: String = "", line: UInt = #line) {
    do { if let v = try a() { note("expected nil got <\(v)> \(m)", line) } } catch { note("threw", line) }
}
func XCTAssertNotNil<T>(_ a: @autoclosure () throws -> T?, _ m: String = "", line: UInt = #line) {
    do { if try a() == nil { note("expected a value \(m)", line) } } catch { note("threw", line) }
}
func XCTAssertGreaterThan<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, line: UInt = #line) { if let x = try? a(), let y = try? b(), x > y {} else { note("not greater", line) } }
func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, line: UInt = #line) { if let x = try? a(), let y = try? b(), x >= y {} else { note("not >=", line) } }
func XCTAssertLessThan<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, line: UInt = #line) { if let x = try? a(), let y = try? b(), x < y {} else { note("not less", line) } }
func XCTAssertLessThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, line: UInt = #line) { if let x = try? a(), let y = try? b(), x <= y {} else { note("not <=", line) } }
func XCTUnwrap<T>(_ a: @autoclosure () throws -> T?, _ m: String = "", line: UInt = #line) throws -> T { guard let v = try a() else { note("unwrap nil", line); throw Unwrap() }; return v }
func XCTFail(_ m: String = "", line: UInt = #line) { note("fail \(m)", line) }
func XCTAssertThrowsError<T>(_ a: @autoclosure () throws -> T, line: UInt = #line) { do { _ = try a(); note("did not throw", line) } catch {} }

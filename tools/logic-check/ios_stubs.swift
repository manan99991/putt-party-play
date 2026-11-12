// Stand-ins so the plain-Foundation parts of the builder compile off-device (Linux has none of these).
final class NSDataDetector {
    init(types: UInt64) throws {}
    func firstMatch(in s: String, options: NSRegularExpression.MatchingOptions = [], range: NSRange) -> NSTextCheckingResult? { nil }
    func matches(in s: String, options: NSRegularExpression.MatchingOptions = [], range: NSRange) -> [NSTextCheckingResult] { [] }
}
extension NSTextCheckingResult {
    var phoneNumber: String? { nil }
    var date: Date? { nil }
    var duration: TimeInterval { 0 }
    var url: URL? { nil }
}

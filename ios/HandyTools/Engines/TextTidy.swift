import Foundation

/// Plain-text helpers behind the Tidy text, Find details and Spreadsheet blocks. All pure and deterministic,
/// so they are unit-tested off-device, and the Android twin (`TextTidy.kt`) uses the same rules.
enum TextTidy {
    /// Collapses runs of spaces, trims every line, removes blank gaps and repeated lines (ignoring case).
    static func clean(_ text: String) -> String {
        var seen = Set<String>()
        var out: [String] = []
        var lastBlank = true            // also drops blank lines at the very top
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            if line.isEmpty {
                if !lastBlank { out.append(""); lastBlank = true }
                continue
            }
            guard seen.insert(line.lowercased()).inserted else { continue }
            out.append(line); lastBlank = false
        }
        while out.last == "" { out.removeLast() }
        return out.joined(separator: "\n")
    }

    struct Details: Equatable {
        var links: [String] = []
        var emails: [String] = []
        var phones: [String] = []
        var isEmpty: Bool { links.isEmpty && emails.isEmpty && phones.isEmpty }
        /// One section per kind that was found, e.g. "Links\nhttps://..."
        var text: String {
            [("Links", links), ("Emails", emails), ("Phones", phones)]
                .filter { !$0.1.isEmpty }
                .map { $0.0 + "\n" + $0.1.joined(separator: "\n") }
                .joined(separator: "\n\n")
        }
    }

    // A phone number is 10 digits (optionally with a country code), not part of a longer digit run,
    // so a card or account number is never mistaken for one.
    private static let phonePattern = #"(?<!\d)(?:\+?\d{1,3}[\s.-]?)?(?:\(\d{3}\)|\d{3})[\s.-]?\d{3}[\s.-]?\d{4}(?!\d)"#
    private static let emailPattern = #"[A-Z0-9._%+-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)*\.[A-Z]{2,}"#
    private static let linkPattern = #"(?:https?://|www\.)[^\s<>"']+"#

    static func details(_ text: String) -> Details {
        Details(
            links: unique(DataGrab.matches(linkPattern, in: text, options: .caseInsensitive).map(trimTail)),
            emails: unique(DataGrab.matches(emailPattern, in: text, options: .caseInsensitive)),
            phones: unique(DataGrab.matches(phonePattern, in: text).map { $0.trimmingCharacters(in: .whitespaces) }))
    }

    /// Sentence punctuation that ends a link in running text is not part of the link.
    private static func trimTail(_ s: String) -> String {
        var t = s
        while let l = t.last, ".,;:!?)".contains(l) { t.removeLast() }
        return t
    }

    private static func unique(_ a: [String]) -> [String] {
        var seen = Set<String>()
        return a.filter { seen.insert($0.lowercased()).inserted }
    }
}

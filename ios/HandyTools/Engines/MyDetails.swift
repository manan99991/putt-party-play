import Foundation

/// The details forms keep asking for, typed once and kept only on this phone (file protection on). A form field is
/// matched to one by its own label — "Surname", "E-mail address", "Postcode", "Date of birth" — and only empty
/// fields are filled, so nothing you typed is overwritten.
struct MyDetails: Codable, Equatable {
    var first = "", last = "", email = "", phone = "", street = "", city = "", region = "", postcode = "", country = "", birth = ""

    static var url: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("my-details.json")
    }
    static func load() -> MyDetails { (try? JSONDecoder().decode(MyDetails.self, from: Data(contentsOf: url))) ?? MyDetails() }
    func save() { try? JSONEncoder().encode(self).write(to: Self.url, options: [.completeFileProtection, .atomic]) }
    var isEmpty: Bool { self == MyDetails() }

    /// The value for a field, from its label. Order matters: "first name" before "name", "date of birth" before "date".
    func value(for label: String, today: Date = Date()) -> String? {
        let l = label.lowercased().replacingOccurrences(of: #"[_\-.:]+"#, with: " ", options: .regularExpression)
        func has(_ p: String) -> Bool { l.range(of: p, options: .regularExpression) != nil }
        let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        let pick: String?
        if has(#"\b(first|given|fore)\s?name\b"#) { pick = first }
        else if has(#"\b(last|family|sur)\s?name\b|\bsurname\b"#) { pick = last }
        else if has(#"\be\s?mail\b"#) { pick = email }
        else if has(#"\b(phone|mobile|cell|tel|telephone)\b"#) { pick = phone }
        else if has(#"\b(birth|dob|born)\b"#) { pick = birth }
        else if has(#"\b(post\s?code|zip|postal)\b"#) { pick = postcode }
        else if has(#"\b(city|town)\b"#) { pick = city }
        else if has(#"\b(state|county|province|region)\b"#) { pick = region }
        else if has(#"\bcountry\b"#) { pick = country }
        else if has(#"\b(address|street)\b"#) { pick = street }
        else if has(#"\b(full\s?name|your\s?name|name of applicant|applicant|^name$|^name\b)"#) { pick = full }
        else if has(#"\b(date|today)\b"#) && !has(#"\b(expir|issue|start|end|from|to)\b"#) { pick = today.formatted(date: .numeric, time: .omitted) }
        else { pick = nil }
        return (pick?.isEmpty ?? true) ? nil : pick
    }
}

import Foundation
import Contacts

/// One-tap "Act on it" writer that saves a task's person to Contacts. The field map — a name guessed from
/// the task plus any number and email it names — is pure and unit-tested; only the save touches the
/// Contacts store, behind the permission the app already requests (ContactsEngine.requestAccess). It never
/// dead-ends: with no number or email there is nothing to save (field returns nil, so the button is
/// hidden), and a denied permission is reported so the UI can point to Settings. The guessed name is a
/// best effort the person can rename in Contacts.
enum ThinkingContacts {
    struct Field: Equatable {
        let name: String
        let phone: String?
        let email: String?
    }

    /// Lead verbs and filler stripped before guessing a name, so "call the dentist" → "Dentist".
    private static let filler: Set<String> = [
        "call", "text", "phone", "ring", "dial", "email", "message", "ask", "contact", "reach", "follow",
        "up", "with", "the", "to", "a", "about", "re",
    ]

    /// A best-effort contact from a task, or nil when there's no number or email to save.
    static func field(for task: ThinkingEngine.Task) -> Field? {
        let phone = task.actions.phone
        let email = ThinkingActions.emailIn(task.text)
        guard phone != nil || email != nil else { return nil }
        return Field(name: guessName(task.text, phone: phone, email: email), phone: phone, email: email)
    }

    /// Guess a contact name: the email's local part when there is an email (landlord@… → "Landlord"),
    /// otherwise the first meaningful word left after dropping the lead verb, the number and the email.
    static func guessName(_ task: String, phone: String?, email: String?) -> String {
        if let email, let local = email.split(separator: "@").first {
            let letters = local.split { !$0.isLetter }.map(String.init).filter { !$0.isEmpty }
            if let first = letters.first { return first.prefix(1).uppercased() + first.dropFirst() }
        }
        var s = task
        if let phone { s = s.replacingOccurrences(of: phone, with: " ") }
        if let email { s = s.replacingOccurrences(of: email, with: " ") }
        let words = s.split { !$0.isLetter }.map(String.init).filter { !filler.contains($0.lowercased()) }
        if let first = words.first { return first.prefix(1).uppercased() + first.dropFirst() }
        return "New contact"
    }

    enum AddError: Error { case denied, failed }

    /// Save the contact (given name + phone + email) behind the app's Contacts permission.
    @MainActor static func add(_ field: Field) async throws {
        guard await ContactsEngine.requestAccess() else { throw AddError.denied }
        let c = CNMutableContact()
        c.givenName = field.name
        if let phone = field.phone {
            c.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))]
        }
        if let email = field.email {
            c.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        }
        let save = CNSaveRequest()
        save.add(c, toContainerWithIdentifier: nil)
        do { try CNContactStore().execute(save) } catch { throw AddError.failed }
    }
}

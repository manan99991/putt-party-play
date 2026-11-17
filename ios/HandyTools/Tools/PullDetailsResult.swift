import SwiftUI
import Contacts

/// The result card for "Pull links, emails and phones": every item it found is a tappable action — open a
/// link, call or message a number, email an address, or save a number/email straight to Contacts — instead
/// of a block of text to copy out by hand. Everything happens on the phone.
struct PullDetailsResult: View {
    let text: String
    @Environment(\.openURL) private var openURL
    @State private var pending: PendingContact?

    private var details: TextTidy.Details { TextTidy.details(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if !details.links.isEmpty {
                section("Links", "link") { ForEach(details.links, id: \.self) { linkRow($0) } }
            }
            if !details.emails.isEmpty {
                section("Emails", "envelope") { ForEach(details.emails, id: \.self) { emailRow($0) } }
            }
            if !details.phones.isEmpty {
                section("Phones", "phone") { ForEach(details.phones, id: \.self) { phoneRow($0) } }
            }
            CopyButton(text: text)
        }
        .sheet(item: $pending) { p in ContactAddSheet(contact: p.contact).ignoresSafeArea() }
    }

    @ViewBuilder private func section<Content: View>(_ title: String, _ icon: String, @ViewBuilder _ rows: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label(title, systemImage: icon).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            rows()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s12)
    }

    private func linkRow(_ s: String) -> some View {
        HStack(spacing: HandySpacing.s8) {
            Text(s).font(HandyFont.body).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: HandySpacing.s8)
            Button { if let u = linkURL(s) { openURL(u) } } label: { Label(L("Open"), systemImage: "arrow.up.right.square") }
                .font(HandyFont.caption).buttonStyle(.borderless)
        }
    }

    private func emailRow(_ s: String) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Text(s).font(HandyFont.body).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: HandySpacing.s8)
            Button { if let u = URL(string: "mailto:\(s)") { openURL(u) } } label: { Image(systemName: "envelope") }.buttonStyle(.borderless)
            Button { pending = PendingContact(contact: contact(email: s)) } label: { Image(systemName: "person.crop.circle.badge.plus") }.buttonStyle(.borderless)
        }
    }

    private func phoneRow(_ s: String) -> some View {
        HStack(spacing: HandySpacing.s12) {
            Text(s).font(HandyFont.body)
            Spacer(minLength: HandySpacing.s8)
            if let u = scheme("tel", s) { Button { openURL(u) } label: { Image(systemName: "phone") }.buttonStyle(.borderless) }
            if let u = scheme("sms", s) { Button { openURL(u) } label: { Image(systemName: "message") }.buttonStyle(.borderless) }
            Button { pending = PendingContact(contact: contact(phone: s)) } label: { Image(systemName: "person.crop.circle.badge.plus") }.buttonStyle(.borderless)
        }
    }

    // MARK: - Helpers

    private func linkURL(_ s: String) -> URL? {
        URL(string: s.lowercased().hasPrefix("http") ? s : "https://\(s)")
    }
    private func scheme(_ scheme: String, _ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "\(scheme):\(digits)")
    }
    private func contact(phone: String) -> CNContact {
        let c = CNMutableContact()
        c.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        return c
    }
    private func contact(email: String) -> CNContact {
        let c = CNMutableContact()
        c.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        return c
    }
}

/// Identifiable wrapper so a tapped contact can drive a `.sheet(item:)`.
private struct PendingContact: Identifiable {
    let id = UUID()
    let contact: CNContact
}

import SwiftUI
import UIKit

/// Long-press a QR code anywhere in the app to see what it holds — a link, a Wi-Fi network, a contact,
/// a phone number — WITHOUT opening it. A safety feature: you check a code's contents before you ever
/// act on it. One path for every QR, whether Tenzy made it or you imported/scanned one, decoded on the
/// fly with ChainExtras.readCode so there is nothing extra to plumb through.

/// The decoded contents of a QR, classified for a readable, safe preview.
struct QRPreviewContent {
    enum Kind { case link, wifi, contact, phone, email, sms, geo, text }
    let kind: Kind
    let title: String      // "Link", "Wi-Fi network", …
    let icon: String       // SF Symbol
    let detail: String     // the main readable content
    let extra: [String]    // supporting lines (host, password, phone…)
    let url: URL?          // set only for an http/https link the user may choose to open

    static func parse(_ raw: String) -> QRPreviewContent {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = s.lowercased()

        if lower.hasPrefix("wifi:") {
            let f = wifiFields(s)
            var extra: [String] = []
            if let t = f["T"], !t.isEmpty { extra.append("Security: \(t)") }
            if let p = f["P"], !p.isEmpty { extra.append("Password: \(p)") }
            if f["H"]?.lowercased() == "true" { extra.append("Hidden network") }
            return .init(kind: .wifi, title: "Wi-Fi network", icon: "wifi",
                         detail: f["S"].map { $0.isEmpty ? "(unnamed)" : $0 } ?? "(unnamed)", extra: extra, url: nil)
        }
        if lower.hasPrefix("begin:vcard") || lower.hasPrefix("mecard:") {
            return .init(kind: .contact, title: "Contact card", icon: "person.crop.circle",
                         detail: vcardName(s) ?? "Contact", extra: vcardLines(s), url: nil)
        }
        if lower.hasPrefix("tel:") {
            return .init(kind: .phone, title: "Phone number", icon: "phone", detail: String(s.dropFirst(4)), extra: [], url: nil)
        }
        if lower.hasPrefix("mailto:") {
            return .init(kind: .email, title: "Email", icon: "envelope", detail: String(s.dropFirst(7)), extra: [], url: nil)
        }
        if lower.hasPrefix("smsto:") || lower.hasPrefix("sms:") {
            return .init(kind: .sms, title: "Text message", icon: "message", detail: s, extra: [], url: nil)
        }
        if lower.hasPrefix("geo:") {
            return .init(kind: .geo, title: "Location", icon: "mappin.and.ellipse", detail: s, extra: [], url: nil)
        }
        if let u = URL(string: s), let scheme = u.scheme?.lowercased(), scheme == "http" || scheme == "https", u.host != nil {
            return .init(kind: .link, title: "Link", icon: "link", detail: s, extra: [u.host ?? ""].filter { !$0.isEmpty }, url: u)
        }
        return .init(kind: .text, title: "Text", icon: "text.alignleft", detail: s, extra: [], url: nil)
    }

    private static func wifiFields(_ s: String) -> [String: String] {
        var body = s
        if body.lowercased().hasPrefix("wifi:") { body = String(body.dropFirst(5)) }
        var out: [String: String] = [:]
        for part in body.components(separatedBy: ";") {
            guard let c = part.firstIndex(of: ":") else { continue }
            let k = String(part[..<c]).uppercased()
            let v = String(part[part.index(after: c)...])
            if !k.isEmpty && !v.isEmpty && out[k] == nil { out[k] = v }
        }
        return out
    }
    private static func vcardName(_ s: String) -> String? {
        for line in s.components(separatedBy: CharacterSet(charactersIn: "\r\n")) {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.uppercased().hasPrefix("FN:") { return String(l.dropFirst(3)) }
            if l.uppercased().hasPrefix("N:") { return l.dropFirst(2).split(separator: ";").reversed().joined(separator: " ").trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }
    private static func vcardLines(_ s: String) -> [String] {
        var out: [String] = []
        for line in s.components(separatedBy: CharacterSet(charactersIn: "\r\n")) {
            let l = line.trimmingCharacters(in: .whitespaces); let up = l.uppercased()
            guard let c = l.firstIndex(of: ":") else { continue }
            let v = String(l[l.index(after: c)...])
            if up.hasPrefix("TEL") { out.append("Phone: \(v)") }
            else if up.hasPrefix("EMAIL") { out.append("Email: \(v)") }
            else if up.hasPrefix("ORG") { out.append("Org: \(v)") }
        }
        return out
    }
}

/// The preview card itself. Shows what the code holds; a link is never opened on its own — the user
/// taps an explicit, clearly-labelled Open button for that.
struct QRPreviewSheet: View {
    let content: QRPreviewContent
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s16) {
            HStack(spacing: HandySpacing.s12) {
                ZStack {
                    Circle().fill(HandyColor.accentSoft).frame(width: 44, height: 44)
                    Image(systemName: content.icon).font(.system(size: 20)).foregroundStyle(HandyColor.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Inside this QR code")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    Text(content.title).font(HandyFont.title)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(content.detail).font(.system(.body, design: content.kind == .link ? .monospaced : .default))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(content.extra, id: \.self) { line in
                        Text(line).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.frame(maxHeight: 180)

            CopyButton(text: content.url?.absoluteString ?? content.detail)

            if let url = content.url {
                // Checked on the phone before anything opens: who really owns the site, and any warning signs.
                let v = ScamAnalyzer.verdict(for: url)
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(L("Goes to")) \(v.owner)", systemImage: v.risky ? "exclamationmark.triangle.fill" : (v.knownSafe ? "checkmark.shield.fill" : "globe"))
                        .font(HandyFont.bodyStrong).foregroundStyle(v.risky ? HandyColor.danger : (v.knownSafe ? HandyColor.success : HandyColor.textPrimary))
                    ForEach(v.issues, id: \.self) { Text("• " + L($0)).font(HandyFont.caption).foregroundStyle(HandyColor.danger).fixedSize(horizontal: false, vertical: true) }
                    if !v.risky {
                        Text(L(v.knownSafe ? "A well-known site's own address." : "No warning signs found — still only open it if you trust where it came from."))
                            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button { UIApplication.shared.open(url) } label: {
                    Label(L(v.risky ? "Open anyway" : "Open link"), systemImage: "safari").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            Button(L("Done")) { dismiss() }.textButton().frame(maxWidth: .infinity)
        }
        .padding(HandySpacing.gutter)
        .background(Ground())
    }
}

private struct QRLongPressPreview: ViewModifier {
    let image: () -> UIImage?
    @State private var content: QRPreviewContent?
    @State private var show = false
    @State private var notFound = false
    func body(content body: Content) -> some View {
        body
            .onLongPressGesture(minimumDuration: 0.4) {
                if let img = image(), let raw = ChainExtras.readCode(img), !raw.isEmpty {
                    content = QRPreviewContent.parse(raw); show = true; HandyHaptics.light()
                } else {
                    notFound = true; HandyHaptics.light()
                }
            }
            .sheet(isPresented: $show) {
                if let content {
                    QRPreviewSheet(content: content)
                        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                }
            }
            .alert(L("No QR code here"), isPresented: $notFound) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(L("Long-press a QR code to see what it holds without opening it."))
            }
    }
}

extension View {
    /// Long-press this view (a QR image) to preview the code's contents without opening them. Pass a
    /// closure that returns the current image so it's decoded only on the press, never up front.
    func qrLongPressPreview(_ image: @escaping () -> UIImage?) -> some View {
        modifier(QRLongPressPreview(image: image))
    }
}

/// Attaches the long-press QR preview only when `enabled` (a QR-making result), so an ordinary photo
/// result doesn't pop a "no QR here" alert when someone long-presses it.
struct QRPeekIfCode: ViewModifier {
    let enabled: Bool
    let image: UIImage
    func body(content: Content) -> some View {
        if enabled { content.qrLongPressPreview({ image }) } else { content }
    }
}

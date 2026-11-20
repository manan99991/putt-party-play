import SwiftUI

/// The finish for a made code — the same in QR & Wi‑Fi, every ready-made code tool and any built tool that makes a
/// code: the code itself, tested by reading it back the way a phone camera would, what it does when scanned
/// (join this network, add this contact, open this page), then Save to Photos, Share, or a printable card for Wi‑Fi.
struct CodeFinishCard: View {
    let image: UIImage

    @State private var decoded: String?
    @State private var tested = false
    @State private var saved: String?

    private var wifi: (ssid: String, pass: String, sec: String)? {
        guard let d = decoded, case .wifi(let ssid, let pass, let sec) = QRPayload.parse(d), !ssid.isEmpty else { return nil }
        return (ssid, pass, sec)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).frame(maxWidth: .infinity)
                .padding(HandySpacing.s16).background(.white, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
            if !tested {
                ProgressView(L("Testing it like a phone camera…")).frame(maxWidth: .infinity)
            } else {
                Label {
                    Text(decoded != nil ? L("Tested — a phone camera reads it") : L("Couldn't read it back — make it bigger or use fewer words"))
                        .font(HandyFont.caption)
                } icon: {
                    Image(systemName: decoded != nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(decoded != nil ? Color.green : Color.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("code-tested")
                if let decoded {
                    Text(L("When someone scans it")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    QRResultCard(raw: decoded)
                }
            }
            if let png = image.pngData() {
                ShareLink(item: PNGFile(data: png), preview: SharePreview("QR code")) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.primaryButton()
                Button {
                    Task { let ok = await PhotoSaver.save(png); saved = L(ok ? "Saved to Photos." : "Couldn't save — allow Tenzy to add photos in Settings.") }
                } label: { Label(L("Save to Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let w = wifi, let card = QRGen.wifiCard(ssid: w.ssid, password: w.pass, security: w.sec == "Open" ? "nopass" : w.sec), let cpng = card.pngData() {
                ShareLink(item: PNGFile(data: cpng), preview: SharePreview("Wi‑Fi card")) {
                    Label(L("Printable card for guests"), systemImage: "printer").frame(maxWidth: .infinity)
                }.secondaryButton()
            }
            if let saved { Text(saved).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("code-finish")
        .task(id: ObjectIdentifier(image)) {
            let img = image
            let found = await Task.detached(priority: .userInitiated) { ChainExtras.readCode(img) }.value
            decoded = found; tested = true
        }
    }
}

/// The finish for a "chat without saving the number" link: open the chat now, or share the link or its code.
struct ChatLinkFinishCard: View {
    let link: String
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Label(L("Chat link ready"), systemImage: "message.fill").font(HandyFont.bodyStrong)
            Text(link).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            if let u = URL(string: link) {
                Link(destination: u) { Label(L("Open the chat in WhatsApp"), systemImage: "arrow.up.right.square").frame(maxWidth: .infinity) }.primaryButton()
                    .accessibilityIdentifier("chat-open")
            }
            HStack(spacing: HandySpacing.s8) {
                CopyButton(text: link)
                ShareLink(item: link) { Label(L("Share"), systemImage: "square.and.arrow.up") }.compactButton()
            }
            Text(L("The number is never saved to your contacts.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            if let qr = QRGen.make(link, scale: 10) { CodeFinishCard(image: qr) }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat-finish")
    }
}

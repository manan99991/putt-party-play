import SwiftUI
import UIKit
import Network

/// A tiny localhost web server that serves ONE configuration profile with the right MIME type, so
/// opening its URL makes iOS show the native "download a configuration profile" → Install flow —
/// the only way an app can add a real home-screen icon, and far cleaner than a share sheet.
final class ProfileServer {
    private var listener: NWListener?
    private let payload: Data
    private let filename: String

    init?(data: Data, filename: String) {
        self.payload = data
        self.filename = filename
        listener = try? NWListener(using: .tcp)
        if listener == nil { return nil }
    }

    func start(_ completion: @escaping (UInt16?) -> Void) {
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: completion(self?.listener?.port?.rawValue)
            case .failed, .cancelled: completion(nil)
            default: break
            }
        }
        listener?.newConnectionHandler = { [weak self] conn in self?.serve(conn) }
        listener?.start(queue: .main)
    }

    private func serve(_ conn: NWConnection) {
        conn.start(queue: .main)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] _, _, _, _ in
            guard let self else { return }
            let header = "HTTP/1.1 200 OK\r\n" +
                "Content-Type: application/x-apple-aspen-config\r\n" +
                "Content-Disposition: attachment; filename=\"\(self.filename)\"\r\n" +
                "Content-Length: \(self.payload.count)\r\n" +
                "Connection: close\r\n\r\n"
            var out = Data(header.utf8); out.append(self.payload)
            conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    func stop() { listener?.cancel(); listener = nil }
}

/// iOS has no API to drop an icon on the home screen, but a Web Clip configuration profile can —
/// with a custom name, a custom icon, and full-screen launch that Safari's "Add to Home Screen"
/// doesn't give you. We build it and hand it to iOS's own installer in one tap.
struct WebClipView: View {
    @State private var url = ""
    @State private var name = ""
    @State private var icon: UIImage?
    @State private var loading = false
    @State private var fullScreen = true
    @State private var status: String?
    @State private var server: ProfileServer?
    @FocusState private var editingName: Bool

    var body: some View {
        ToolPage(title: "Web → Home", subtitle: "Paste a link. Pick the name and icon. One tap installs it — opens full-screen like a real app, which Safari can't do.") {
            TextField("https://…", text: $url)
                .padding(HandySpacing.s12)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            HStack(spacing: HandySpacing.s12) {
                Button("Paste") { if let s = UIPasteboard.general.string, let m = s.range(of: #"https?://\S+"#, options: .regularExpression) { url = String(s[m]); Task { await fetch() } } }
                Button("Fetch") { Task { await fetch() } }.compactButton().disabled(url.isEmpty || loading)
                if loading { ProgressView() }
            }

            if icon != nil || !name.isEmpty {
                VStack(spacing: HandySpacing.s8) {
                    ZStack {
                        LinearGradient(colors: [HandyColor.accent.opacity(0.9), HandyColor.accentPressed], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: 160, height: 160).clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        if let icon { Image(uiImage: icon).resizable().frame(width: 62, height: 62).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                    }
                    Text(name.isEmpty ? " " : name).font(.system(size: 12)).foregroundStyle(HandyColor.textPrimary)
                }.frame(maxWidth: .infinity)

                TextField("Name", text: $name)
                    .focused($editingName)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingName = false }.fontWeight(.semibold) } }

                Toggle("Open full-screen (no Safari bars)", isOn: $fullScreen).tint(HandyColor.accent).font(HandyFont.body)

                Button { installProfile() } label: { Label("Add to home screen", systemImage: "plus.app").frame(maxWidth: .infinity) }.primaryButton()
            }

            if let status {
                VStack(alignment: .leading, spacing: 4) {
                    if status == "ready" {
                        Text("Safari just opened — two taps to finish:").font(.callout.bold())
                        Text("1. Tap Allow when it offers the profile.")
                        Text("2. Settings › Profile Downloaded › Install. (“Not Signed” is normal.)")
                    } else {
                        Text("Couldn't start the installer. Try the Safari route below.").font(.callout).foregroundStyle(HandyColor.danger)
                    }
                }.font(.callout)
                Button("Can't install profiles? Open in Safari and use Share › Add to Home Screen") { if let u = URL(string: normalized) { UIApplication.shared.open(u) } }
                    .textButton().font(HandyFont.caption)
            }
        }
    }

    private var normalized: String { url.hasPrefix("http") ? url : "https://\(url)" }
    private var safeName: String { let s = name.filter { $0.isLetter || $0.isNumber }; return s.isEmpty ? "shortcut" : s }

    private func fetch() async {
        guard let u = URL(string: normalized) else { return }
        loading = true; defer { loading = false }
        let host = u.host?.replacingOccurrences(of: "www.", with: "") ?? "Site"
        var title = host.components(separatedBy: ".").first?.capitalized ?? "Site"
        var iconURL = URL(string: "https://www.google.com/s2/favicons?sz=256&domain=\(host)")
        if let (data, _) = try? await URLSession.shared.data(from: u), let html = String(data: data.prefix(200_000), encoding: .utf8) {
            if let t = match(html, #"<meta[^>]+property=["']og:site_name["'][^>]+content=["']([^"']+)"#) ?? match(html, #"<title[^>]*>([^<]{1,100})</title>"#) {
                title = t
                for sep in [" – ", " - ", " — ", " | "] { title = title.components(separatedBy: sep).first ?? title }
                title = title.trimmingCharacters(in: .whitespaces)
            }
            if let href = match(html, #"<link[^>]+rel=["']apple-touch-icon[^"']*["'][^>]+href=["']([^"']+)"#), let abs = URL(string: href, relativeTo: u) { iconURL = abs.absoluteURL }
        }
        name = String(title.prefix(30))
        if let iu = iconURL, let (d, _) = try? await URLSession.shared.data(from: iu) { icon = UIImage(data: d) }
    }

    private func match(_ s: String, _ pattern: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let g = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[g]).replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Build the Web Clip profile and serve it over localhost so iOS opens its native installer.
    private func installProfile() {
        let iconData = icon.flatMap { $0.pngData() } ?? UIImage(systemName: "globe")!.pngData()!
        let id = "com.tenzy.webclip.\(UUID().uuidString.prefix(8))"
        let plist: [String: Any] = [
            "PayloadContent": [[
                "FullScreen": fullScreen, "IsRemovable": true, "Label": name, "URL": normalized, "Icon": iconData,
                "PayloadDescription": "Adds \(name) to your home screen", "PayloadDisplayName": name,
                "PayloadIdentifier": "\(id).clip", "PayloadType": "com.apple.webClip.managed", "PayloadUUID": UUID().uuidString, "PayloadVersion": 1,
            ]],
            "PayloadDescription": "Home-screen shortcut for \(name), made by Tenzy. Remove anytime in Settings › General › VPN & Device Management.",
            "PayloadDisplayName": "\(name) — Home Screen Icon", "PayloadIdentifier": id, "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration", "PayloadUUID": UUID().uuidString, "PayloadVersion": 1,
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { status = "err"; return }

        server?.stop()
        let srv = ProfileServer(data: data, filename: "\(safeName).mobileconfig")
        server = srv
        srv?.start { port in
            guard let port, let u = URL(string: "http://127.0.0.1:\(port)/\(safeName).mobileconfig") else { status = "err"; return }
            status = "ready"; HandyHaptics.success()
            UIApplication.shared.open(u)
            Interstitials.shared.showIfReady()
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { srv?.stop() }
        }
    }
}

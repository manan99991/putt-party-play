import SwiftUI
import UIKit

/// iOS has no API to add a home-screen shortcut. Two honest routes:
///   1. Generate a signed-less .mobileconfig "Web Clip" profile. User taps it → Settings installs it →
///      icon appears, with the name + icon we auto-picked. Works on every iPhone, no jailbreak.
///   2. Open the link in Safari and walk the user through Share › Add to Home Screen.
/// We offer both. Route 1 is the "paste and boom" one.
struct WebClipView: View {
    @State private var url = ""
    @State private var name = ""
    @State private var icon: UIImage?
    @State private var loading = false
    @State private var profileURL: URL?
    @State private var status: String?

    var body: some View {
        ToolPage(title: "Web → Home", subtitle: "Paste a link. We pick the name and icon. Install the profile, and it's on your home screen.") {
            TextField("https://…", text: $url).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1)).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            HStack(spacing: HandySpacing.s12) {
                Button("Paste") { if let s = UIPasteboard.general.string, let m = s.range(of: #"https?://\S+"#, options: .regularExpression) { url = String(s[m]); Task { await fetch() } } }
                Button("Fetch") { Task { await fetch() } }.compactButton().disabled(url.isEmpty || loading)
                if loading { ProgressView() }
            }
            if icon != nil || !name.isEmpty {
                HStack(spacing: HandySpacing.s12) {
                    if let icon { Image(uiImage: icon).resizable().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous)) }
                    TextField("Name", text: $name).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }
                Button { makeProfile() } label: { Label("Add to home screen", systemImage: "plus.app").frame(maxWidth: .infinity) }
                    .primaryButton()
                Button("Or: open in Safari and use Share › Add to Home Screen") { if let u = URL(string: normalized) { UIApplication.shared.open(u) } }.textButton().font(HandyFont.caption)
            }
            if status != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile ready. Three taps to finish:").font(.callout.bold())
                    Text("1. In the sheet, choose Save to Files.")
                    Text("2. Open the file in Files.")
                    Text("3. Settings › Profile Downloaded › Install. (\"Not Signed\" is normal for home-screen profiles.)")
                }.font(.callout)
            }
            if let p = profileURL { ShareLink(item: p) { Label("Share / save profile again", systemImage: "square.and.arrow.up") }.font(.footnote) }
        }
    }

    private var normalized: String { url.hasPrefix("http") ? url : "https://\(url)" }

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

    /// Builds a Web Clip configuration profile and hands it to the system installer.
    private func makeProfile() {
        let iconData = icon.flatMap { $0.pngData() } ?? UIImage(systemName: "globe")!.pngData()!
        let id = "com.handytools.webclip.\(UUID().uuidString.prefix(8))"
        let plist: [String: Any] = [
            "PayloadContent": [[
                "FullScreen": false, "IsRemovable": true, "Label": name, "URL": normalized, "Icon": iconData,
                "PayloadDescription": "Adds \(name) to your home screen", "PayloadDisplayName": name,
                "PayloadIdentifier": "\(id).clip", "PayloadType": "com.apple.webClip.managed", "PayloadUUID": UUID().uuidString, "PayloadVersion": 1,
            ]],
            "PayloadDescription": "Home screen shortcut for \(name), made by HandyTools. Remove anytime in Settings › General › VPN & Device Management.",
            "PayloadDisplayName": "\(name) — Home Screen Icon", "PayloadIdentifier": id, "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration", "PayloadUUID": UUID().uuidString, "PayloadVersion": 1,
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(name.filter { $0.isLetter || $0.isNumber }).mobileconfig")
        try? data.write(to: file)
        profileURL = file
        status = "ready"
        // Hand the file to the system; tapping it from Files triggers the profile installer.
        let av = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first?
            .present(av, animated: true)
        Interstitials.shared.showIfReady()
    }
}

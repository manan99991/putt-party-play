import Foundation

/// Strips tracking from shared links (utm_*, fbclid, gclid, Amazon ref tags, …) and unwraps the
/// common redirect wrappers, so what you paste is the page, not the surveillance.
enum LinkCleaner {
    static let junkParams: Set<String> = ["fbclid", "gclid", "gclsrc", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid", "yclid", "twclid", "ttclid", "_hsenc", "_hsmi", "hsctatracking", "mkt_tok", "ref", "ref_", "ref_src", "ref_url", "spm", "si", "feature", "trk", "trkCampaign", "_ga", "_gl", "vero_id", "wickedid", "oly_anon_id", "oly_enc_id", "s_kwcid", "ncid", "cmpid", "rb_clickid", "sc_cid", "soc_src", "soc_trk", "pd_rd_r", "pd_rd_w", "pd_rd_wg", "pf_rd_p", "pf_rd_r", "psc", "th", "linkCode", "tag", "linkId", "ascsubtag", "sr", "qid", "keywords", "crid", "sprefix", "dib", "dib_tag"]
    static let junkPrefixes = ["utm_", "pk_", "piwik_", "matomo_", "mtm_", "ga_", "hsa_", "_bta_", "oly_", "vero_", "at_", "ito"]
    /// Hosts whose only job is to wrap the real URL in a query parameter.
    static let wrappers: [(host: String, param: String)] = [("l.facebook.com", "u"), ("lm.facebook.com", "u"), ("l.instagram.com", "u"), ("www.google.com", "url"), ("google.com", "url"), ("out.reddit.com", "url"), ("href.li", ""), ("t.umblr.com", "z"), ("exit.sc", "url"), ("www.youtube.com", "q"), ("youtube.com", "q"), ("l.messenger.com", "u"), ("safelinks.protection.outlook.com", "url"), ("urldefense.com", "")]

    static func clean(_ raw: String) -> String {
        guard var comps = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return raw }
        // unwrap redirectors
        if let host = comps.host?.lowercased(), let w = wrappers.first(where: { host == $0.host || host.hasSuffix("." + $0.host) }) {
            if !w.param.isEmpty, let inner = comps.queryItems?.first(where: { $0.name == w.param })?.value, let innerURL = URLComponents(string: inner), innerURL.host != nil {
                return clean(inner)
            }
        }
        // amazon: keep only the /dp/ASIN path
        if let host = comps.host?.lowercased(), host.contains("amazon."), let r = comps.path.range(of: #"/(dp|gp/product)/([A-Z0-9]{10})"#, options: .regularExpression) {
            let asin = String(comps.path[r]).split(separator: "/").last.map(String.init) ?? ""
            comps.path = "/dp/" + asin; comps.queryItems = nil; comps.fragment = nil
            return comps.string ?? raw
        }
        if let items = comps.queryItems {
            let kept = items.filter { q in
                let n = q.name.lowercased()
                return !(junkParams.contains(q.name) || junkParams.contains(n) || junkPrefixes.contains { n.hasPrefix($0) })
            }
            comps.queryItems = kept.isEmpty ? nil : kept
        }
        if comps.host?.lowercased().hasSuffix("youtube.com") == true || comps.host?.lowercased() == "youtu.be" { /* keep v/t */ }
        if let f = comps.fragment, f.hasPrefix("xtor=") || f.hasPrefix("Echobox") || f.hasPrefix(":~:") { comps.fragment = nil }
        var s = comps.string ?? raw
        if s.hasSuffix("?") { s.removeLast() }
        return s
    }

    static func isURL(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.contains(" ") && !t.contains("\n") && (t.hasPrefix("http://") || t.hasPrefix("https://")) && URL(string: t)?.host != nil
    }
}

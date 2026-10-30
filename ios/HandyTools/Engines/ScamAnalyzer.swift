import Foundation

/// Explains *why* a message smells like a scam. Pure rules (urgency, payment rails, credential
/// asks, impersonation, link tricks) that run on the phone with no network, each producing a
/// human-readable finding — so the verdict is teachable, not a black box.
enum ScamAnalyzer {
    struct Finding: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String
        let weight: Int          // 1 mild … 4 severe
        static func == (a: Finding, b: Finding) -> Bool { a.title == b.title && a.detail == b.detail }
    }
    enum Verdict: String { case likelyScam = "Likely a scam", suspicious = "Suspicious", lowRisk = "Looks low-risk" }
    struct Report { let score: Int; let verdict: Verdict; let findings: [Finding]; let links: [LinkCheck] }
    struct LinkCheck: Identifiable, Equatable { let id = UUID(); let url: String; let host: String; let issues: [String]
        static func == (a: LinkCheck, b: LinkCheck) -> Bool { a.url == b.url && a.issues == b.issues } }

    static func analyze(_ raw: String) -> Report {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        var f: [Finding] = []

        func hit(_ patterns: [String]) -> [String] { patterns.filter { lower.range(of: $0, options: .regularExpression) != nil } }

        // 1. urgency / threats
        let urgency = hit([#"\bimmediately\b"#, #"\bwithin (24|48) hours\b"#, #"\bact now\b"#, #"\burgent"#, #"\bfinal (notice|warning)\b"#, #"\bsuspend(ed)?\b"#, #"\bwill be (closed|locked|terminated|deactivated)\b"#, #"\blast chance\b"#, #"\bexpires? (today|soon|in)\b"#, #"\blegal action\b"#, #"\barrest"#, #"\bwarrant\b"#])
        if !urgency.isEmpty { f.append(Finding(title: "Pressure to act fast", detail: "Scams manufacture urgency so you don't stop to check. Real companies give you time and a way to verify.", weight: urgency.count > 1 ? 3 : 2)) }

        // 1b. legal / authority threats — "arrest", "warrant", "SSN suspended". These words almost
        // never appear in a legitimate text, so a threat on its own is worth flagging.
        let threat = hit([#"\barrest"#, #"\bwarrant\b"#, #"\blegal action\b"#, #"\blawsuit\b"#, #"\bpolice\b"#, #"\bprosecut"#, #"\bcourt (date|case|summons|hearing)\b"#, #"\b(ssn|social security)\b(\s+\w+){0,5}\s+suspend"#, #"\bsuspend(\s+\w+){0,5}\s+(ssn|social security)\b"#, #"\bdeport"#, #"\bface (arrest|charges|prosecution|a fine)\b"#])
        let callToAction = hit([#"\bcall (now|immediately|us|this number|back|the)\b"#, #"\bpress \d\b"#, #"\bpay\b"#, #"\bclick\b"#, #"\btap\b"#, #"\bverify\b"#, #"\bconfirm\b"#, #"\brespond\b"#, #"\breply\b"#, #"\bdo not ignore\b"#, #"\bact now\b"#, #"\bclaim\b"#])
        // A threat only counts when it is paired with pressure or a demand to act — a passing
        // mention ("jury duty packet arrived", "police charity drive") is not a scam.
        if !threat.isEmpty && (!urgency.isEmpty || !callToAction.isEmpty) { f.append(Finding(title: "Threatens you with legal trouble", detail: "Real agencies send letters and never threaten arrest by text or demand you act on the spot. This is pure pressure.", weight: 3)) }

        // 2. payment rails — only alarming when a payment is actually being demanded.
        // (A newsletter that mentions "bitcoin", or a friend naming "Venmo", is not a scam.)
        let demand = hit([#"\b(pay|send|transfer|deposit|wire|load|reload|settle|owe|owed)\b"#, #"\bpayment\b"#, #"\b(processing |small |admin(istration)?|release |activation )?fee\b"#, #"\bbalance (due|outstanding)\b"#])
        let hasDemand = !demand.isEmpty
        let railHard = hit([#"gift ?cards?"#, #"\bitunes\b"#, #"\bgoogle play card"#, #"\bsteam card"#, #"\bwire transfer\b"#, #"\bwestern union\b"#, #"\bmoneygram\b"#])
        let railSoft = hit([#"\bzelle\b"#, #"\bcash ?app\b"#, #"\bvenmo\b"#, #"\bprepaid\b"#, #"\bbitcoin\b"#, #"\bcrypto"#, #"\busdt\b"#, #"\bwallet address\b"#])
        let railHit = !railHard.isEmpty || (!railSoft.isEmpty && hasDemand)
        if railHit {
            let w = (!railHard.isEmpty && (hasDemand || !urgency.isEmpty)) || (!railSoft.isEmpty && hasDemand) ? 4 : 2
            f.append(Finding(title: "Asks for an untraceable payment", detail: "Gift cards, crypto, wire transfers and payment apps can't be reversed. No government agency, utility or tech company takes payment that way.", weight: w))
        }

        // 3. credentials / codes / personal data — the scam is SOLICITING these, not merely
        // mentioning them. A one-time code that is simply sent to you ("your code is 1234") is an
        // everyday message; being asked to hand a code back, or to "verify" via a message, is not.
        let codeSolicit = hit([#"\b(send|share|read|tell|give|provide|confirm|enter|type|forward|repeat)\b(\s+\w+){0,4}\s+code\b"#, #"\b(sent|texted|emailed) (you )?(a|the|your) code\b"#, #"\bcode (we|i|they) (sent|texted|emailed)\b"#, #"\bcode\b(\s+\w+){0,3}\s+(back|to me|to us)\b"#, #"\bwhat('?s| is| was)?( the)? code\b"#, #"\bcode you (just )?(got|received)\b"#])
        let credAsk = hit([#"\b(enter|confirm|verify|update|provide|re-?enter|submit|validate) your (password|pin|ssn|social security|card number|cvv|cvc|billing|payment|bank|account|identity|details|information|credentials)\b"#, #"\bverify your (account|identity)\b"#, #"\bconfirm your (account|identity)\b"#, #"\byour (password|account) (has|is|will)\b(\s+\w+){0,4}\s+(expired?|suspend(ed)?|lock(ed)?|disabled?|compromis(ed)?)"#, #"\bupdate your (billing|payment) (details|information|method)\b"#])
        let creds = codeSolicit + credAsk
        if !codeSolicit.isEmpty { f.append(Finding(title: "Wants a code, password or personal details", detail: "Nobody legitimate asks you to read back a one-time code or type your password into a link they sent. Codes are the keys to your accounts.", weight: 4)) }
        else if !credAsk.isEmpty { f.append(Finding(title: "Pushes you to \"verify\" your account", detail: "Being told to confirm or verify your account through a message is how fake login pages get filled in. Open the app or type the site address yourself instead.", weight: 3)) }

        // 4. impersonation of institutions
        let brands = hit([#"\b(irs|hmrc|ato|cra|social security administration|medicare|dmv|usps|ups|fedex|dhl|royal mail|amazon|apple|microsoft|paypal|netflix|bank|chase|wells fargo|barclays|hsbc|coinbase|geek squad|norton|mcafee)\b"#])
        let genericGreeting = hit([#"^(dear (customer|user|member|account holder|sir|madam)|hello (customer|user|friend))"#, #"\bdear (customer|user|member|account holder)\b"#])
        if !brands.isEmpty && (!urgency.isEmpty || !creds.isEmpty || railHit) { f.append(Finding(title: "Claims to be a well-known organisation", detail: "Impersonating a bank, delivery firm, tax office or tech company is the standard opener. Contact them through the number on your card or their official app — never the one in the message.", weight: 2)) }
        if !genericGreeting.isEmpty { f.append(Finding(title: "Generic greeting", detail: "\"Dear customer\" means they don't know your name — a mass-sent message.", weight: 1)) }

        // 5. too good to be true / advance fee / romance / job
        let lottery = hit([#"\byou('ve| have) (won|been selected|been chosen)\b"#, #"\bcongratulations\b"#, #"\blottery\b"#, #"\bprize\b"#, #"\binheritance\b"#, #"\bclaim your\b"#, #"\bfree (iphone|gift|money|reward)\b"#, #"\bguaranteed (return|profit|income)\b"#, #"\bdouble your\b"#, #"\bearn \$?\d{3,}.{0,20}(day|week|hour)\b"#, #"\bwork from home\b.{0,40}\$"#, #"\bprocessing fee\b"#, #"\bsmall fee\b"#, #"\bunlock (the )?funds\b"#])
        if !lottery.isEmpty { f.append(Finding(title: "Too good to be true", detail: "Prizes you didn't enter, guaranteed returns, and fees to release money are the oldest tricks in the book.", weight: 3)) }

        // 5b. employment / "task" scams — big daily/weekly/monthly pay, no experience, and "apply by
        // texting a keyword to this number". These rarely trip the other signals, so a blatant job
        // scam used to score 0 and read as "low-risk". Detect the combination directly.
        let jobContext = hit([#"\b(hiring|now hiring|job offer|positions?|vacanc(y|ies)|recruit(ing|ment)?|employment|work from home|remote (job|work|position)|part[\s-]?time|full[\s-]?time|applicants?|apply now|openings?|daily pay|monthly income|side (job|gig|hustle)|training provided|no experience (needed|required|necessary)?)\b"#])
        let hasBigPay = lower.range(of: #"\$\s?\d{3,}"#, options: .regularExpression) != nil || lower.range(of: #"\$\s?\d{1,3},\d{3}"#, options: .regularExpression) != nil
        let payPeriod = !hit([#"\b(daily|/\s?day|per day|a day|weekly|per week|a week|hourly|per hour|an hour|monthly|per month|a month)\b"#]).isEmpty
        let applyByText = lower.range(of: #"\b(text|txt|sms|message|whats\s?app|telegram|dm|reply|respond)\b[^.\n]{0,40}\bto\s+\+?\d[\d\s().\-]{5,}"#, options: .regularExpression) != nil
        if !jobContext.isEmpty && ((hasBigPay && payPeriod) || applyByText) {
            let strong = (hasBigPay && payPeriod) && applyByText
            f.append(Finding(title: "Job offer that's too good to be true", detail: "Hundreds a day with no experience, and \"text a word to this number to apply\", is the signature of a job or task scam. Real employers interview you and never promise that kind of pay up front or hire over a text keyword.", weight: strong ? 4 : 3))
        }

        // 6. secrecy / isolation
        let secrecy = hit([#"\b(do not|don'?t) tell (anyone|anybody|your family|your (wife|husband|kids|son|daughter)|the bank)\b"#, #"\bkeep (this|it) (confidential|secret|between us)\b"#, #"\bdo not (hang up|disconnect)\b"#, #"\bstay on the (line|phone)\b"#])
        if !secrecy.isEmpty { f.append(Finding(title: "Tells you to keep it secret", detail: "Isolation keeps you from the one friend or family member who'd say \"that's a scam\".", weight: 4)) }

        // 7. wrong-number / relationship openers
        let openers = hit([#"^(hi|hello|hey)[,!.]? (is this|are you) [a-z]+\??$"#, #"\bwrong number\b"#, #"\bsorry,? who is this\b"#, #"\blong time no see\b"#])
        if !openers.isEmpty && text.count < 160 { f.append(Finding(title: "Wrong-number opener", detail: "\"Is this Sarah?\" from an unknown number is how long-con investment and romance scams start a conversation.", weight: 2)) }

        // 8. unsolicited attachments / remote access
        let remote = hit([#"\b(anydesk|teamviewer|remote (access|desktop)|screen ?share|install (this|the) app)\b"#, #"\brefund\b.{0,60}\b(form|install|download)\b"#])
        if !remote.isEmpty { f.append(Finding(title: "Wants remote access or an install", detail: "Remote-access tools hand over your whole phone or computer. Refund and tech-support scams depend on this step.", weight: 4)) }

        // 9. links
        let links = linkChecks(in: text)
        let linkIssues = links.flatMap(\.issues)
        if !linkIssues.isEmpty { f.append(Finding(title: "Link looks wrong", detail: linkIssues.prefix(3).joined(separator: " "), weight: 3)) }
        else if !links.isEmpty, !creds.isEmpty || !urgency.isEmpty { f.append(Finding(title: "Link plus pressure", detail: "A link you didn't ask for, paired with urgency, is the phishing formula. Type the site address yourself instead.", weight: 2)) }

        // 10. spelling / shouting (mild)
        let caps = text.filter { $0.isUppercase }.count, letters = text.filter { $0.isLetter }.count
        if letters > 40, Double(caps) / Double(letters) > 0.45 { f.append(Finding(title: "Shouting", detail: "Lots of capitals and exclamation marks are a pressure tactic.", weight: 1)) }

        // Corroboration: real scams stack several signals. A lone, ordinary-sounding keyword
        // should not raise an alarm — that is the main source of false "it's a scam" calls.
        let strongTitles: Set<String> = ["Asks for an untraceable payment", "Tells you to keep it secret", "Wants remote access or an install", "Wants a code, password or personal details", "Link looks wrong", "Threatens you with legal trouble", "Job offer that's too good to be true"]
        let hasStrong = f.contains { strongTitles.contains($0.title) && $0.weight >= 3 }
        var score = min(100, f.reduce(0) { $0 + $1.weight * 12 })
        if f.count <= 1 && !hasStrong { score = min(score, 18) }                            // one lone soft signal → low-risk
        else if !hasStrong && (f.map(\.weight).max() ?? 0) <= 2 { score = min(score, 32) }   // only mild signals → cap near the floor
        let verdict: Verdict = score >= 55 ? .likelyScam : score >= 30 ? .suspicious : .lowRisk
        return Report(score: score, verdict: verdict, findings: f.sorted { $0.weight > $1.weight }, links: links)
    }

    // MARK: links

    static let trustedBrands = ["paypal", "apple", "amazon", "microsoft", "google", "netflix", "chase", "wellsfargo", "barclays", "hsbc", "usps", "fedex", "ups", "dhl", "irs", "coinbase", "facebook", "instagram", "whatsapp"]
    static let shorteners: Set<String> = ["bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly", "cutt.ly", "rb.gy", "shorturl.at", "tiny.cc", "rebrand.ly"]

    static func linkChecks(in text: String) -> [LinkCheck] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        var out: [LinkCheck] = []
        for m in det.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let u = m.url, let scheme = u.scheme?.lowercased(), scheme == "http" || scheme == "https", let host = u.host?.lowercased() else { continue }
            var issues: [String] = []
            if scheme == "http" { issues.append("Not encrypted (http://).") }
            if host.hasPrefix("xn--") || host.contains(".xn--") { issues.append("Uses look-alike (punycode) characters in the address.") }
            if shorteners.contains(host) { issues.append("A shortened link hides where it really goes.") }
            if host.range(of: #"^\d{1,3}(\.\d{1,3}){3}$"#, options: .regularExpression) != nil { issues.append("Points at a bare IP address, not a company domain.") }
            let labels = host.split(separator: ".").map(String.init)
            let registrable = labels.suffix(2).joined(separator: ".")
            for b in trustedBrands where host.contains(b) && !registrable.hasPrefix(b + ".") {
                issues.append("\"\(b)\" appears in the address but the real site is \(registrable) — a classic look-alike.")
                break
            }
            if labels.count >= 4 { issues.append("Unusually deep sub-domain — the real owner is \(registrable).") }
            if let tld = labels.last, ["zip", "mov", "top", "xyz", "click", "link", "gq", "tk", "ml", "cf", "buzz"].contains(tld) { issues.append("Ends in .\(tld), a domain ending heavily used by scammers.") }
            if u.path.lowercased().range(of: #"(login|verify|secure|account|update|confirm|wallet)"#, options: .regularExpression) != nil, issues.isEmpty == false || !trustedBrands.contains(where: { registrable.hasPrefix($0 + ".") }) {
                issues.append("Path says \"\(u.path.split(separator: "/").first.map(String.init) ?? "login")\" — pages like this are where credentials get stolen.")
            }
            out.append(LinkCheck(url: u.absoluteString, host: host, issues: Array(Set(issues)).sorted()))
        }
        return out
    }

    /// What to do next, matched to the findings.
    static func advice(for r: Report) -> [String] {
        var a: [String] = []
        if r.findings.contains(where: { $0.title.contains("code, password") }) { a.append("Never read a code aloud or type it into a link. If you already did, change that password now and turn on two-factor.") }
        if r.findings.contains(where: { $0.title.contains("untraceable") }) { a.append("Stop before paying. If a payment was made, call the card issuer or app immediately — minutes matter.") }
        if r.findings.contains(where: { $0.title.contains("well-known") }) { a.append("Call the organisation using the number on your card, statement or official app — not from this message.") }
        if !r.links.isEmpty { a.append("Don't tap the link. Open the site by typing its address yourself.") }
        if r.verdict == .lowRisk { a.append("Nothing obviously wrong, but if it asks for money or details later, run it through here again.") }
        a.append("Reply nothing. Block and report the sender.")
        return r.verdict == .lowRisk ? Array(a.prefix(1)) : a
    }
}

package com.handytools.app.tools.shield

/**
 * Explains *why* a message smells like a scam. Pure rules (urgency, payment rails, credential
 * asks, impersonation, link tricks, look-alike sender addresses) that run on the phone with no
 * network — each producing a human-readable finding, so the verdict is teachable, not a black box.
 *
 * Faithful Kotlin port of the iOS ScamAnalyzer, extended on Android to also judge bare links,
 * phone numbers and email sender addresses pasted on their own. Nothing is ever uploaded.
 */
object ScamAnalyzer {

    data class Finding(val title: String, val detail: String, val weight: Int) // 1 mild … 4 severe

    enum class Verdict(val label: String) {
        LIKELY_SCAM("Likely a scam"),
        SUSPICIOUS("Suspicious"),
        LOW_RISK("Looks low-risk"),
    }

    data class LinkCheck(val url: String, val host: String, val issues: List<String>)
    data class Report(val score: Int, val verdict: Verdict, val findings: List<Finding>, val links: List<LinkCheck>)

    private fun hit(lower: String, patterns: List<String>): List<String> =
        patterns.filter { Regex(it).containsMatchIn(lower) }

    fun analyze(raw: String): Report {
        val text = raw.trim()
        val lower = text.lowercase()
        val f = ArrayList<Finding>()

        // 1. urgency / threats
        val urgency = hit(lower, listOf(
            """\bimmediately\b""", """\bwithin (24|48) hours\b""", """\bact now\b""", """\burgent""",
            """\bfinal (notice|warning)\b""", """\bsuspend(ed)?\b""",
            """\bwill be (closed|locked|terminated|deactivated)\b""", """\blast chance\b""",
            """\bexpires? (today|soon|in)\b""", """\blegal action\b""", """\barrest""", """\bwarrant\b""",
        ))
        if (urgency.isNotEmpty()) f.add(Finding(
            "Pressure to act fast",
            "Scams manufacture urgency so you don't stop to check. Real companies give you time and a way to verify.",
            if (urgency.size > 1) 3 else 2,
        ))

        // 1b. legal / authority threats — only when paired with pressure or a demand to act.
        val threat = hit(lower, listOf(
            """\barrest""", """\bwarrant\b""", """\blegal action\b""", """\blawsuit\b""", """\bpolice\b""",
            """\bprosecut""", """\bcourt (date|case|summons|hearing)\b""",
            """\b(ssn|social security)\b(\s+\w+){0,5}\s+suspend""",
            """\bsuspend(\s+\w+){0,5}\s+(ssn|social security)\b""", """\bdeport""",
            """\bface (arrest|charges|prosecution|a fine)\b""",
        ))
        val callToAction = hit(lower, listOf(
            """\bcall (now|immediately|us|this number|back|the)\b""", """\bpress \d\b""", """\bpay\b""",
            """\bclick\b""", """\btap\b""", """\bverify\b""", """\bconfirm\b""", """\brespond\b""",
            """\breply\b""", """\bdo not ignore\b""", """\bact now\b""", """\bclaim\b""",
        ))
        if (threat.isNotEmpty() && (urgency.isNotEmpty() || callToAction.isNotEmpty())) f.add(Finding(
            "Threatens you with legal trouble",
            "Real agencies send letters and never threaten arrest by text or demand you act on the spot. This is pure pressure.",
            3,
        ))

        // 2. payment rails — only alarming when a payment is actually being demanded.
        val demand = hit(lower, listOf(
            """\b(pay|send|transfer|deposit|wire|load|reload|settle|owe|owed)\b""", """\bpayment\b""",
            """\b(processing |small |admin(istration)?|release |activation )?fee\b""",
            """\bbalance (due|outstanding)\b""",
        ))
        val hasDemand = demand.isNotEmpty()
        val railHard = hit(lower, listOf(
            """gift ?cards?""", """\bitunes\b""", """\bgoogle play card""", """\bsteam card""",
            """\bwire transfer\b""", """\bwestern union\b""", """\bmoneygram\b""",
        ))
        val railSoft = hit(lower, listOf(
            """\bzelle\b""", """\bcash ?app\b""", """\bvenmo\b""", """\bprepaid\b""", """\bbitcoin\b""",
            """\bcrypto""", """\busdt\b""", """\bwallet address\b""",
        ))
        val railHit = railHard.isNotEmpty() || (railSoft.isNotEmpty() && hasDemand)
        if (railHit) {
            val w = if ((railHard.isNotEmpty() && (hasDemand || urgency.isNotEmpty())) || (railSoft.isNotEmpty() && hasDemand)) 4 else 2
            f.add(Finding(
                "Asks for an untraceable payment",
                "Gift cards, crypto, wire transfers and payment apps can't be reversed. No government agency, utility or tech company takes payment that way.",
                w,
            ))
        }

        // 3. credentials / codes / personal data — the scam is SOLICITING these, not mentioning them.
        val codeSolicit = hit(lower, listOf(
            """\b(send|share|read|tell|give|provide|confirm|enter|type|forward|repeat)\b(\s+\w+){0,4}\s+code\b""",
            """\b(sent|texted|emailed) (you )?(a|the|your) code\b""",
            """\bcode (we|i|they) (sent|texted|emailed)\b""",
            """\bcode\b(\s+\w+){0,3}\s+(back|to me|to us)\b""",
            """\bwhat('?s| is| was)?( the)? code\b""",
            """\bcode you (just )?(got|received)\b""",
        ))
        val credAsk = hit(lower, listOf(
            """\b(enter|confirm|verify|update|provide|re-?enter|submit|validate) your (password|pin|ssn|social security|card number|cvv|cvc|billing|payment|bank|account|identity|details|information|credentials)\b""",
            """\bverify your (account|identity)\b""",
            """\bconfirm your (account|identity)\b""",
            """\byour (password|account) (has|is|will)\b(\s+\w+){0,4}\s+(expired?|suspend(ed)?|lock(ed)?|disabled?|compromis(ed)?)""",
            """\bupdate your (billing|payment) (details|information|method)\b""",
        ))
        val creds = codeSolicit + credAsk
        if (codeSolicit.isNotEmpty()) f.add(Finding(
            "Wants a code, password or personal details",
            "Nobody legitimate asks you to read back a one-time code or type your password into a link they sent. Codes are the keys to your accounts.",
            4,
        )) else if (credAsk.isNotEmpty()) f.add(Finding(
            "Pushes you to \"verify\" your account",
            "Being told to confirm or verify your account through a message is how fake login pages get filled in. Open the app or type the site address yourself instead.",
            3,
        ))

        // 4. impersonation of institutions
        val brands = hit(lower, listOf(
            """\b(irs|hmrc|ato|cra|social security administration|medicare|dmv|usps|ups|fedex|dhl|royal mail|amazon|apple|microsoft|paypal|netflix|bank|chase|wells fargo|barclays|hsbc|coinbase|geek squad|norton|mcafee)\b""",
        ))
        val genericGreeting = hit(lower, listOf(
            """^(dear (customer|user|member|account holder|sir|madam)|hello (customer|user|friend))""",
            """\bdear (customer|user|member|account holder)\b""",
        ))
        if (brands.isNotEmpty() && (urgency.isNotEmpty() || creds.isNotEmpty() || railHit)) f.add(Finding(
            "Claims to be a well-known organisation",
            "Impersonating a bank, delivery firm, tax office or tech company is the standard opener. Contact them through the number on your card or their official app — never the one in the message.",
            2,
        ))
        if (genericGreeting.isNotEmpty()) f.add(Finding(
            "Generic greeting",
            "\"Dear customer\" means they don't know your name — a mass-sent message.",
            1,
        ))

        // 5. too good to be true / advance fee / romance / job
        val lottery = hit(lower, listOf(
            """\byou('ve| have) (won|been selected|been chosen)\b""", """\bcongratulations\b""",
            """\blottery\b""", """\bprize\b""", """\binheritance\b""", """\bclaim your\b""",
            """\bfree (iphone|gift|money|reward)\b""", """\bguaranteed (return|profit|income)\b""",
            """\bdouble your\b""", """\bearn \${'$'}?\d{3,}.{0,20}(day|week|hour)\b""",
            """\bwork from home\b.{0,40}\${'$'}""", """\bprocessing fee\b""", """\bsmall fee\b""",
            """\bunlock (the )?funds\b""",
        ))
        if (lottery.isNotEmpty()) f.add(Finding(
            "Too good to be true",
            "Prizes you didn't enter, guaranteed returns, and fees to release money are the oldest tricks in the book.",
            3,
        ))

        // 5b. employment / "task" scams — big pay, no experience, "text a keyword to this number".
        val jobContext = hit(lower, listOf(
            """\b(hiring|now hiring|job offer|positions?|vacanc(y|ies)|recruit(ing|ment)?|employment|work from home|remote (job|work|position)|part[\s-]?time|full[\s-]?time|applicants?|apply now|openings?|daily pay|monthly income|side (job|gig|hustle)|training provided|no experience (needed|required|necessary)?)\b""",
        ))
        val hasBigPay = Regex("""\${'$'}\s?\d{3,}""").containsMatchIn(lower) ||
            Regex("""\${'$'}\s?\d{1,3},\d{3}""").containsMatchIn(lower)
        val payPeriod = hit(lower, listOf(
            """\b(daily|/\s?day|per day|a day|weekly|per week|a week|hourly|per hour|an hour|monthly|per month|a month)\b""",
        )).isNotEmpty()
        val applyByText = Regex(
            """\b(text|txt|sms|message|whats\s?app|telegram|dm|reply|respond)\b[^.\n]{0,40}\bto\s+\+?\d[\d\s().\-]{5,}"""
        ).containsMatchIn(lower)
        if (jobContext.isNotEmpty() && ((hasBigPay && payPeriod) || applyByText)) {
            val strong = (hasBigPay && payPeriod) && applyByText
            f.add(Finding(
                "Job offer that's too good to be true",
                "Hundreds a day with no experience, and \"text a word to this number to apply\", is the signature of a job or task scam. Real employers interview you and never promise that kind of pay up front or hire over a text keyword.",
                if (strong) 4 else 3,
            ))
        }

        // 6. secrecy / isolation
        val secrecy = hit(lower, listOf(
            """\b(do not|don'?t) tell (anyone|anybody|your family|your (wife|husband|kids|son|daughter)|the bank)\b""",
            """\bkeep (this|it) (confidential|secret|between us)\b""",
            """\bdo not (hang up|disconnect)\b""", """\bstay on the (line|phone)\b""",
        ))
        if (secrecy.isNotEmpty()) f.add(Finding(
            "Tells you to keep it secret",
            "Isolation keeps you from the one friend or family member who'd say \"that's a scam\".",
            4,
        ))

        // 7. wrong-number / relationship openers
        val openers = hit(lower, listOf(
            """^(hi|hello|hey)[,!.]? (is this|are you) [a-z]+\??${'$'}""",
            """\bwrong number\b""", """\bsorry,? who is this\b""", """\blong time no see\b""",
        ))
        if (openers.isNotEmpty() && text.length < 160) f.add(Finding(
            "Wrong-number opener",
            "\"Is this Sarah?\" from an unknown number is how long-con investment and romance scams start a conversation.",
            2,
        ))

        // 8. unsolicited attachments / remote access
        val remote = hit(lower, listOf(
            """\b(anydesk|teamviewer|remote (access|desktop)|screen ?share|install (this|the) app)\b""",
            """\brefund\b.{0,60}\b(form|install|download)\b""",
        ))
        if (remote.isNotEmpty()) f.add(Finding(
            "Wants remote access or an install",
            "Remote-access tools hand over your whole phone or computer. Refund and tech-support scams depend on this step.",
            4,
        ))

        // 9. links
        val links = linkChecks(text)
        val linkIssues = links.flatMap { it.issues }
        if (linkIssues.isNotEmpty()) f.add(Finding(
            "Link looks wrong",
            linkIssues.take(3).joinToString(" "),
            3,
        )) else if (links.isNotEmpty() && (creds.isNotEmpty() || urgency.isNotEmpty())) f.add(Finding(
            "Link plus pressure",
            "A link you didn't ask for, paired with urgency, is the phishing formula. Type the site address yourself instead.",
            2,
        ))

        // 9b. email sender look-alikes (Android extension)
        val emailDomains = Regex("""[a-z0-9._%+\-]+@([a-z0-9.\-]+\.[a-z]{2,})""").findAll(lower).map { it.groupValues[1] }.toList()
        for (dom in emailDomains) {
            val labels = dom.split(".")
            val registrable = labels.takeLast(2).joinToString(".")
            val brand = trustedBrands.firstOrNull { dom.contains(it) && !registrable.startsWith("$it.") }
            if (brand != null) {
                f.add(Finding(
                    "Sender's address is faked",
                    "The address contains \"$brand\" but the real domain is $registrable — a look-alike built to pass a glance.",
                    3,
                ))
                break
            } else if (registrable in freeMailHosts && brands.isNotEmpty()) {
                f.add(Finding(
                    "Brand message from a free email account",
                    "A message claiming to be a company but sent from a free $registrable address is almost always fake.",
                    2,
                ))
                break
            }
        }

        // 10. spelling / shouting (mild)
        val caps = text.count { it.isUpperCase() }
        val letters = text.count { it.isLetter() }
        if (letters > 40 && caps.toDouble() / letters.toDouble() > 0.45) f.add(Finding(
            "Shouting",
            "Lots of capitals and exclamation marks are a pressure tactic.",
            1,
        ))

        // Corroboration: real scams stack several signals. A lone soft keyword should not alarm.
        val strongTitles = setOf(
            "Asks for an untraceable payment", "Tells you to keep it secret",
            "Wants remote access or an install", "Wants a code, password or personal details",
            "Link looks wrong", "Threatens you with legal trouble",
            "Job offer that's too good to be true", "Sender's address is faked",
        )
        val hasStrong = f.any { it.title in strongTitles && it.weight >= 3 }
        var score = minOf(100, f.sumOf { it.weight * 12 })
        if (f.size <= 1 && !hasStrong) score = minOf(score, 18)
        else if (!hasStrong && (f.maxOfOrNull { it.weight } ?: 0) <= 2) score = minOf(score, 32)
        val verdict = if (score >= 55) Verdict.LIKELY_SCAM else if (score >= 30) Verdict.SUSPICIOUS else Verdict.LOW_RISK
        return Report(score, verdict, f.sortedByDescending { it.weight }, links)
    }

    // MARK: links

    private val trustedBrands = listOf(
        "paypal", "apple", "amazon", "microsoft", "google", "netflix", "chase", "wellsfargo",
        "barclays", "hsbc", "usps", "fedex", "ups", "dhl", "irs", "coinbase", "facebook",
        "instagram", "whatsapp",
    )
    private val shorteners = setOf(
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly", "cutt.ly",
        "rb.gy", "shorturl.at", "tiny.cc", "rebrand.ly",
    )
    private val scamTlds = setOf("zip", "mov", "top", "xyz", "click", "link", "gq", "tk", "ml", "cf", "buzz")
    private val freeMailHosts = setOf(
        "gmail.com", "outlook.com", "hotmail.com", "yahoo.com", "proton.me", "protonmail.com",
        "icloud.com", "aol.com", "gmx.com", "mail.com", "yandex.com",
    )
    // Known TLDs: lets us treat a scheme-less token like "paypal.secure-login.top/verify" as a link
    // without flagging ordinary prose such as "Mr.Smith" or "etc.".
    private val knownTlds = setOf(
        "com", "net", "org", "io", "co", "gov", "edu", "info", "biz", "us", "uk", "ca", "de",
        "fr", "au", "in", "ru", "cn", "jp", "br", "it", "es", "nl", "se", "no", "me", "tv",
        "app", "dev", "online", "site", "shop", "live", "store", "pro", "xyz", "top", "click",
        "link", "zip", "mov", "gq", "tk", "ml", "cf", "buzz", "icu", "cc", "ws", "cyou", "sbs",
    )

    fun linkChecks(text: String): List<LinkCheck> {
        // Strip email addresses so their domains aren't mistaken for standalone links.
        val cleaned = Regex("""[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}""", RegexOption.IGNORE_CASE).replace(text, " ")
        val urlRe = Regex("""(?i)\b(https?://)?([a-z0-9][a-z0-9.\-]*\.[a-z]{2,})(/[^\s]*)?""")
        val out = ArrayList<LinkCheck>()
        for (m in urlRe.findAll(cleaned)) {
            val scheme = m.groupValues[1].lowercase()
            val host = m.groupValues[2].lowercase().trimEnd('.')
            val path = m.groupValues[3]
            val labels = host.split(".")
            val tld = labels.last()
            val hadScheme = scheme.isNotEmpty()
            // Accept scheme-less tokens only when they really look like a domain.
            if (!hadScheme && !host.startsWith("www.") && tld !in knownTlds) continue
            if (labels.size < 2) continue

            val issues = ArrayList<String>()
            if (scheme == "http://") issues.add("Not encrypted (http://).")
            if (host.startsWith("xn--") || host.contains(".xn--")) issues.add("Uses look-alike (punycode) characters in the address.")
            if (host in shorteners) issues.add("A shortened link hides where it really goes.")
            if (Regex("""^\d{1,3}(\.\d{1,3}){3}${'$'}""").containsMatchIn(host)) issues.add("Points at a bare IP address, not a company domain.")
            val registrable = labels.takeLast(2).joinToString(".")
            for (b in trustedBrands) {
                if (host.contains(b) && !registrable.startsWith("$b.")) {
                    issues.add("\"$b\" appears in the address but the real site is $registrable — a classic look-alike.")
                    break
                }
            }
            if (labels.size >= 4) issues.add("Unusually deep sub-domain — the real owner is $registrable.")
            if (tld in scamTlds) issues.add("Ends in .$tld, a domain ending heavily used by scammers.")
            val pathLower = path.lowercase()
            val isTrusted = trustedBrands.any { registrable.startsWith("$it.") }
            if (Regex("""(login|verify|secure|account|update|confirm|wallet)""").containsMatchIn(pathLower) && (issues.isNotEmpty() || !isTrusted)) {
                val firstSeg = path.trimStart('/').split("/").firstOrNull().orEmpty().ifEmpty { "login" }
                issues.add("Path says \"$firstSeg\" — pages like this are where credentials get stolen.")
            }
            out.add(LinkCheck(m.value, host, issues.distinct().sorted()))
        }
        return out
    }

    /** What to do next, matched to the findings. */
    fun advice(r: Report): List<String> {
        val a = ArrayList<String>()
        if (r.findings.any { it.title.contains("code, password") }) a.add("Never read a code aloud or type it into a link. If you already did, change that password now and turn on two-factor.")
        if (r.findings.any { it.title.contains("untraceable") }) a.add("Stop before paying. If a payment was made, call the card issuer or app immediately — minutes matter.")
        if (r.findings.any { it.title.contains("well-known") || it.title.contains("faked") }) a.add("Contact the organisation using the number on your card, statement or official app — not from this message.")
        if (r.links.isNotEmpty()) a.add("Don't tap the link. Open the site by typing its address yourself.")
        if (r.verdict == Verdict.LOW_RISK) a.add("Nothing obviously wrong, but if it asks for money or details later, run it through here again.")
        a.add("Reply nothing. Block and report the sender.")
        return if (r.verdict == Verdict.LOW_RISK) a.take(1) else a
    }
}

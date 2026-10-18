import Foundation

/// Plain-English definitions for the jargon that shows up in leases, contracts, bills, insurance
/// letters, lab reports and prescriptions. Powers the Explainer's always-available layer and
/// double-checks the model's output. Definitions are general knowledge, not advice.
enum Glossary {
    struct Term: Identifiable { let id = UUID(); let term: String; let meaning: String; let domain: String }

    static let terms: [Term] = [
        // legal / contracts
        .init(term: "indemnify", meaning: "You promise to cover the other side's losses or legal costs if something goes wrong — often even if it wasn't your fault.", domain: "Legal"),
        .init(term: "hold harmless", meaning: "You agree not to blame or sue them for certain problems.", domain: "Legal"),
        .init(term: "arbitration", meaning: "Disputes go to a private decision-maker instead of a court. Usually you give up the right to sue or join a class action.", domain: "Legal"),
        .init(term: "class action waiver", meaning: "You can't join with other customers to sue as a group.", domain: "Legal"),
        .init(term: "liquidated damages", meaning: "A fixed penalty amount agreed in advance if you break the contract.", domain: "Legal"),
        .init(term: "force majeure", meaning: "Neither side is liable for failures caused by big outside events (storms, war, pandemics).", domain: "Legal"),
        .init(term: "severability", meaning: "If one clause is thrown out by a court, the rest of the contract still stands.", domain: "Legal"),
        .init(term: "non-compete", meaning: "You agree not to work for competitors for a period after leaving.", domain: "Legal"),
        .init(term: "non-solicitation", meaning: "You agree not to recruit their staff or customers after leaving.", domain: "Legal"),
        .init(term: "auto-renew", meaning: "The contract renews itself unless you cancel before a deadline — note the notice period.", domain: "Legal"),
        .init(term: "automatic renewal", meaning: "The contract renews itself unless you cancel before a deadline — note the notice period.", domain: "Legal"),
        .init(term: "termination for convenience", meaning: "One side (check which) can end the deal without needing a reason.", domain: "Legal"),
        .init(term: "jurisdiction", meaning: "Which place's courts and laws apply if there's a dispute.", domain: "Legal"),
        .init(term: "governing law", meaning: "Which place's laws are used to interpret the contract.", domain: "Legal"),
        .init(term: "assignment", meaning: "Handing the contract (or your rights under it) to someone else — often restricted.", domain: "Legal"),
        .init(term: "warranty", meaning: "A promise that something is true or will work; 'as is' means no promise at all.", domain: "Legal"),
        .init(term: "as is", meaning: "No guarantees — you accept it with any faults.", domain: "Legal"),
        .init(term: "consideration", meaning: "What each side gives up to make the deal binding (money, work, a promise).", domain: "Legal"),
        .init(term: "power of attorney", meaning: "Legal permission for someone to act on your behalf.", domain: "Legal"),
        .init(term: "lien", meaning: "A legal claim on your property until a debt is paid.", domain: "Legal"),
        .init(term: "escrow", meaning: "Money held by a neutral third party until conditions are met.", domain: "Legal"),
        .init(term: "security deposit", meaning: "Money the landlord holds against damage or unpaid rent; rules on returning it vary by place.", domain: "Housing"),
        .init(term: "joint and several", meaning: "Each person on the lease is responsible for the whole rent, not just their share.", domain: "Housing"),
        .init(term: "sublet", meaning: "Renting your place (or a room) to someone else — often needs written permission.", domain: "Housing"),
        .init(term: "quiet enjoyment", meaning: "Your right to use the home without the landlord interfering unreasonably.", domain: "Housing"),
        .init(term: "holdover", meaning: "Staying after the lease ends — may trigger higher rent or eviction.", domain: "Housing"),
        .init(term: "notice to quit", meaning: "A formal notice that you must leave by a date.", domain: "Housing"),
        // finance
        .init(term: "apr", meaning: "Annual Percentage Rate — the yearly cost of borrowing including fees, so you can compare offers.", domain: "Finance"),
        .init(term: "variable rate", meaning: "The interest rate can go up or down over time.", domain: "Finance"),
        .init(term: "compound interest", meaning: "Interest charged on interest — balances grow faster than you'd expect.", domain: "Finance"),
        .init(term: "minimum payment", meaning: "The least you can pay without penalty — paying only this can take years and cost a lot in interest.", domain: "Finance"),
        .init(term: "grace period", meaning: "Time after a due date before interest or a penalty kicks in.", domain: "Finance"),
        .init(term: "deductible", meaning: "What you pay out of pocket before insurance starts paying.", domain: "Insurance"),
        .init(term: "copay", meaning: "A fixed amount you pay per visit or prescription.", domain: "Insurance"),
        .init(term: "coinsurance", meaning: "Your percentage share of a bill after the deductible.", domain: "Insurance"),
        .init(term: "out-of-pocket maximum", meaning: "The most you'll pay in a year; after that insurance pays 100% of covered care.", domain: "Insurance"),
        .init(term: "premium", meaning: "The regular price you pay to keep the policy.", domain: "Insurance"),
        .init(term: "prior authorization", meaning: "The insurer must approve a treatment before it's covered.", domain: "Insurance"),
        .init(term: "in-network", meaning: "Providers with a deal with your insurer — cheaper for you.", domain: "Insurance"),
        .init(term: "out-of-network", meaning: "Providers without a deal — you pay much more, sometimes everything.", domain: "Insurance"),
        .init(term: "explanation of benefits", meaning: "A statement from the insurer showing what was billed, what they paid, and what you may owe. It is not a bill.", domain: "Insurance"),
        .init(term: "eob", meaning: "Explanation of Benefits — shows what the insurer paid; not a bill.", domain: "Insurance"),
        .init(term: "pre-existing condition", meaning: "A health issue you had before the policy started.", domain: "Insurance"),
        .init(term: "beneficiary", meaning: "The person who receives the money or benefit.", domain: "Finance"),
        .init(term: "annuity", meaning: "An insurance product that pays you an income, often in exchange for a lump sum.", domain: "Finance"),
        .init(term: "expense ratio", meaning: "The yearly fee a fund takes, as a percentage of your money.", domain: "Finance"),
        .init(term: "vesting", meaning: "How long until the employer's contributions or stock are really yours.", domain: "Finance"),
        .init(term: "escalation clause", meaning: "A price or rent that automatically rises on a schedule.", domain: "Finance"),
        .init(term: "balloon payment", meaning: "A large final payment at the end of a loan.", domain: "Finance"),
        .init(term: "amortization", meaning: "Paying off a loan in regular instalments that cover interest first, then more principal over time.", domain: "Finance"),
        .init(term: "principal", meaning: "The amount borrowed, before interest.", domain: "Finance"),
        .init(term: "arrears", meaning: "Overdue, unpaid amounts.", domain: "Finance"),
        .init(term: "garnishment", meaning: "Money taken directly from wages or an account to pay a debt, by court order.", domain: "Finance"),
        // medical
        .init(term: "benign", meaning: "Not cancerous; not dangerous in itself.", domain: "Medical"),
        .init(term: "malignant", meaning: "Cancerous — can spread.", domain: "Medical"),
        .init(term: "metastasis", meaning: "Cancer that has spread to another part of the body.", domain: "Medical"),
        .init(term: "biopsy", meaning: "Taking a small tissue sample to examine under a microscope.", domain: "Medical"),
        .init(term: "lesion", meaning: "A general word for an area of abnormal tissue — not a diagnosis by itself.", domain: "Medical"),
        .init(term: "unremarkable", meaning: "Normal; nothing of concern was found.", domain: "Medical"),
        .init(term: "within normal limits", meaning: "Normal result.", domain: "Medical"),
        .init(term: "acute", meaning: "Sudden or short-term.", domain: "Medical"),
        .init(term: "chronic", meaning: "Long-lasting or recurring.", domain: "Medical"),
        .init(term: "idiopathic", meaning: "Cause unknown.", domain: "Medical"),
        .init(term: "prognosis", meaning: "The expected course or outcome.", domain: "Medical"),
        .init(term: "contraindicated", meaning: "Should not be used in your situation because it could cause harm.", domain: "Medical"),
        .init(term: "prn", meaning: "As needed (from the Latin pro re nata).", domain: "Medical"),
        .init(term: "bid", meaning: "Twice a day.", domain: "Medical"),
        .init(term: "tid", meaning: "Three times a day.", domain: "Medical"),
        .init(term: "qid", meaning: "Four times a day.", domain: "Medical"),
        .init(term: "po", meaning: "By mouth.", domain: "Medical"),
        .init(term: "npo", meaning: "Nothing by mouth — don't eat or drink (e.g. before surgery).", domain: "Medical"),
        .init(term: "hypertension", meaning: "High blood pressure.", domain: "Medical"),
        .init(term: "hypotension", meaning: "Low blood pressure.", domain: "Medical"),
        .init(term: "hyperlipidemia", meaning: "High cholesterol or other blood fats.", domain: "Medical"),
        .init(term: "edema", meaning: "Swelling from fluid build-up.", domain: "Medical"),
        .init(term: "dyspnea", meaning: "Shortness of breath.", domain: "Medical"),
        .init(term: "tachycardia", meaning: "Fast heart rate.", domain: "Medical"),
        .init(term: "bradycardia", meaning: "Slow heart rate.", domain: "Medical"),
        .init(term: "a1c", meaning: "A blood test showing average blood sugar over about three months.", domain: "Medical"),
        .init(term: "ldl", meaning: "'Bad' cholesterol — lower is generally better.", domain: "Medical"),
        .init(term: "hdl", meaning: "'Good' cholesterol — higher is generally better.", domain: "Medical"),
        .init(term: "cbc", meaning: "Complete blood count — a routine panel of blood cell measurements.", domain: "Medical"),
        .init(term: "bmp", meaning: "Basic metabolic panel — kidney function, blood sugar and electrolytes.", domain: "Medical"),
        .init(term: "tsh", meaning: "Thyroid-stimulating hormone — a thyroid screening test.", domain: "Medical"),
        .init(term: "egfr", meaning: "An estimate of how well the kidneys filter.", domain: "Medical"),
        .init(term: "referral", meaning: "Your doctor sending you to a specialist; sometimes required by insurance.", domain: "Medical"),
        .init(term: "generic", meaning: "The same medicine as the brand version, usually cheaper.", domain: "Medical"),
        .init(term: "formulary", meaning: "The list of medicines your insurance plan covers.", domain: "Insurance"),
        .init(term: "informed consent", meaning: "Agreeing to a procedure after the risks and alternatives were explained.", domain: "Medical"),
        .init(term: "advance directive", meaning: "A document stating your wishes for care if you can't speak for yourself.", domain: "Medical"),
        // employment / government
        .init(term: "at-will", meaning: "Either side can end the job at any time, for almost any legal reason.", domain: "Employment"),
        .init(term: "exempt", meaning: "Not entitled to overtime pay under wage law.", domain: "Employment"),
        .init(term: "non-exempt", meaning: "Entitled to overtime pay.", domain: "Employment"),
        .init(term: "pto", meaning: "Paid time off.", domain: "Employment"),
        .init(term: "cobra", meaning: "US rule letting you keep employer health insurance after leaving, if you pay the full premium.", domain: "Employment"),
        .init(term: "garnish", meaning: "Take money directly from pay to settle a debt.", domain: "Finance"),
        .init(term: "statute of limitations", meaning: "The deadline for bringing a legal claim.", domain: "Legal"),
        .init(term: "affidavit", meaning: "A written statement you swear is true.", domain: "Legal"),
        .init(term: "subpoena", meaning: "A legal order to appear or hand over documents.", domain: "Legal"),
        .init(term: "plaintiff", meaning: "The person bringing the lawsuit.", domain: "Legal"),
        .init(term: "defendant", meaning: "The person being sued or charged.", domain: "Legal"),
        .init(term: "default judgment", meaning: "You lose automatically because you didn't respond in time.", domain: "Legal"),
        .init(term: "pro rata", meaning: "In proportion — e.g. rent charged for only the days you were there.", domain: "Finance"),
        .init(term: "net 30", meaning: "Payment is due 30 days after the invoice date.", domain: "Finance"),
        .init(term: "retainer", meaning: "Money paid upfront to secure a professional's services, drawn down as work is done.", domain: "Legal"),
        .init(term: "waiver", meaning: "Giving up a right on purpose.", domain: "Legal"),
        .init(term: "notwithstanding", meaning: "Despite — 'notwithstanding section 4' means this overrides section 4.", domain: "Legal"),
        .init(term: "herein", meaning: "In this document.", domain: "Legal"),
        .init(term: "thereof", meaning: "Of that thing just mentioned.", domain: "Legal"),
        .init(term: "shall", meaning: "Must (a binding obligation).", domain: "Legal"),
    ]

    /// Terms that appear in the text, longest match first, each once.
    static func found(in text: String) -> [Term] {
        let lower = " " + text.lowercased() + " "
        var seen = Set<String>(), out: [Term] = []
        for t in terms.sorted(by: { $0.term.count > $1.term.count }) where !seen.contains(t.term) {
            let pattern = "(?<![a-z])" + NSRegularExpression.escapedPattern(for: t.term) + "(?![a-z])"
            if lower.range(of: pattern, options: .regularExpression) != nil { seen.insert(t.term); out.append(t) }
        }
        return out
    }

    /// Clauses worth a second look in any contract, with why.
    static func redFlags(in text: String) -> [(String, String)] {
        let checks: [(String, String, String)] = [
            (#"\b(auto(matic(ally)?)?[- ]?renew)"#, "Auto-renewal", "Find the cancellation deadline and set a reminder before it."),
            (#"\b(arbitration|class action)\b"#, "Arbitration / class-action waiver", "You may be giving up the right to go to court."),
            (#"\b(indemnif|hold harmless)"#, "Indemnity", "Check whether you're covering their losses even when it isn't your fault."),
            (#"\b(non[- ]?compete)"#, "Non-compete", "How long, how wide a region, and which employers does it block?"),
            (#"\b(early termination|cancellation) fee"#, "Early-termination fee", "Know the exact amount before you sign."),
            (#"\b(late fee|late charge|penalty interest)"#, "Late fees", "Check the grace period and how the fee is calculated."),
            (#"\b(sole discretion|at (our|its) discretion)"#, "'Sole discretion'", "They can decide this however they like — you have no say."),
            (#"\b(may (change|modify|update) (these|this|the) (terms|agreement|fees?) at any time)"#, "Unilateral changes", "They can change the deal later; see how you'll be notified."),
            (#"\b(waive|waiver of)\b"#, "Waiver", "You're giving something up — find out exactly what."),
            (#"\b(personal guarantee|personally liable|jointly and severally)"#, "Personal liability", "Your own assets may be on the hook, not just the business's or your share."),
            (#"\b(binding|irrevocable)\b"#, "Binding / irrevocable", "Hard or impossible to undo once signed."),
            (#"\b(as is|no warranty|without warranty)\b"#, "No warranty", "No promises about quality — you bear the risk of faults."),
        ]
        let lower = text.lowercased()
        return checks.compactMap { lower.range(of: $0.0, options: .regularExpression) != nil ? ($0.1, $0.2) : nil }
    }
}

import Foundation

/// Home's "Most loved": twelve one-tap jobs. The first visit shows the twelve most people reach for; after that the
/// tools a person really opens move in, so the row is theirs (Manan, 28 Nov).
enum HomePicks {
    struct Pick: Identifiable, Equatable {
        let id: String          // the tool to open, or "myreminders"
        let title: String       // short, fits one line in a quarter of the screen
        let icon: String        // SF Symbol, when the tool has no drawn art
        let hex: UInt32
    }

    /// The first twelve: the jobs with the widest everyday use, each a different job (no two doing the same thing).
    static let starters: [Pick] = [
        Pick(id: "scan", title: "Scan", icon: "doc.viewfinder", hex: 0x3B82F6),
        Pick(id: "cleaner", title: "Free space", icon: "trash", hex: 0x10B981),
        Pick(id: "contacts", title: "Contacts", icon: "person.crop.circle.badge.plus", hex: 0x06B6D4),
        Pick(id: "myreminders", title: "Reminder", icon: "bell.fill", hex: 0x7B5CFF),
        Pick(id: "post", title: "Social video", icon: "play.rectangle.on.rectangle", hex: 0xEC4899),
        Pick(id: "translate", title: "Translate", icon: "character.bubble", hex: 0x3B7BE8),
        Pick(id: "gpsdash", title: "Parked car", icon: "car.fill", hex: 0xF59E0B),
        Pick(id: "sticker", title: "Sticker", icon: "scissors", hex: 0xF97316),
        Pick(id: "collage", title: "Collage", icon: "square.grid.2x2", hex: 0xD946EF),
        Pick(id: "pdfsign", title: "Sign PDF", icon: "signature", hex: 0xEF4444),
        Pick(id: "fileviewer", title: "Open a file", icon: "doc.text", hex: 0x6366F1),
        Pick(id: "vault", title: "Hide photos", icon: "lock.fill", hex: 0x475569),
    ]

    /// Short names for tools that can move in, so every tile stays one line.
    static let shortNames: [String: String] = [
        "identify": "What is it?", "studio": "Fix a photo", "speechnotes": "Voice notes", "memory": "Find a photo",
        "shield": "Scam check", "medreminder": "Medicine", "daydiary": "Mood diary", "rest": "Sleep sounds",
        "thinking": "Think it out", "light": "Flashlight", "menu": "Read a menu", "fitit": "Shrink a file",
        "celebrate": "Video Studio", "video": "Video", "qrwifi": "QR & Wi‑Fi", "procam": "Pro Camera",
        "meetingnotes": "Meeting notes", "voicenotes": "Voice notes", "datagrab": "Grab data", "stitch": "Long shot",
        "scrub": "Privacy", "warranty": "Receipts", "sorted": "Bills", "invoice": "Invoices", "measure": "Measure",
        "pricecheck": "Price check", "trailer": "Trailer", "beatreel": "Beat reel", "funny": "Funny clip",
        "animate": "Animate", "faceemoji": "Face emoji", "audiostudio": "Audio", "pdfform": "Fill a form",
        "pdfconvert": "PDF convert", "zipmaker": "Zip", "ringtone": "Ringtone", "planner": "Checklist",
        "brief": "Morning note", "untangle": "Plan my day", "pricewatch": "Price watch", "mileage": "Miles",
    ]

    private static let key = "tenzy.home.uses"
    /// How often each tool has been opened (any door). Kept on the phone only.
    static var uses: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func noteUse(_ id: String) {
        guard !id.isEmpty, id != "settings" else { return }
        var u = uses; u[id, default: 0] += 1; uses = u
    }

    /// The twelve to show: the starters, with any tool opened at least twice that isn't there taking the place of the
    /// least-used starter it beats. Order stays put, so tiles don't jump around between visits.
    static func current(uses: [String: Int] = uses, known: (String) -> (title: String, icon: String, hex: UInt32)?) -> [Pick] {
        var picks = starters
        let shown = Set(picks.map(\.id))
        let movers = uses.filter { !shown.contains($0.key) && $0.value >= 2 }.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        for (id, count) in movers {
            guard let info = known(id) else { continue }
            // The starter used least (latest in the list on a tie) gives way, if this tool is used more than it.
            let starterIdx = picks.indices.filter { i in starters.contains { $0.id == picks[i].id } }
            guard let weakest = starterIdx.min(by: { a, b in
                let ua = uses[picks[a].id, default: 0], ub = uses[picks[b].id, default: 0]
                return ua != ub ? ua < ub : a > b
            }), uses[picks[weakest].id, default: 0] < count else { break }
            picks[weakest] = Pick(id: id, title: shortNames[id] ?? info.title, icon: info.icon, hex: info.hex)
        }
        return picks
    }
}

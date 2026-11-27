import SwiftUI

/// "Try another look" under a finished result, for tools whose own finish card doesn't already offer one: the same
/// input re-run with one choice changed (a QR's style, a GIF's speed, a summary's length…), so the person picks the
/// best version without starting again. Fun photos, voices, boomerangs, speeds, collages and photo GIFs have their
/// looks on their own cards and aren't listed here.
enum ResultLooks {
    struct Group: Identifiable {
        let step: Int            // which step of the tool the choice belongs to
        let key: String          // the setting it changes
        let title: String
        let options: [(id: String, name: String)]
        let fallback: String     // what the tool used when the setting was never set
        var id: String { "\(step).\(key)" }
    }

    /// The choices offered for this tool's result. `text` is what the last step read (for voices in its language).
    static func groups(_ chain: Chain, text: String?) -> [Group] {
        var out: [Group] = []
        guard let lastIndex = chain.steps.indices.last else { return out }
        let last = chain.steps[lastIndex].block
        func add(_ key: String, _ title: String, _ options: [(id: String, name: String)], _ fallback: String, step: Int = lastIndex) {
            out.append(Group(step: step, key: key, title: title, options: options, fallback: fallback))
        }
        switch last {
        case .videoGif: add("look", "Try another look", ChainText.videoGifLooks, "normal")
        case .makeQr, .wifiQr, .contactQr: add("style", "Try another style", ChainText.qrStyles, "classic")
        case .hideSensitive: add("style", "Cover them with", ChainText.hideStyles, "block")
        case .videoVertical: add("fit", "Try another fit", ChainText.tallFits, "crop")
        case .videoCelebrate: add("theme", "Try another celebration", Celebrate.themes.map { ($0.id, "\($0.emoji) \($0.name)") }, "")
        case .rewrite: add("style", "Try another tone", ChainText.rewriteStyles, "clear")
        case .summarize:
            add("sentences", "How long", ChainText.summaryLengths, "3")
            add("format", "Layout", ChainText.summaryFormats, "text")
        case .readAloud:
            add("speed", "Speed", ChainText.readSpeeds, "normal")
            let voices = text.map(ChainMedia.voiceChoices(for:)) ?? []
            if voices.count > 1 { add("voice", "Voice", voices, voices[0].id) }
        default: break
        }
        // A cut-out product photo: the backdrop it sits on.
        if chain.steps.contains(where: { $0.block == .cutout }), let i = chain.steps.firstIndex(where: { $0.block == .resizePhoto }) {
            add("backdrop", "Try another backdrop", ChainText.backdrops, "white", step: i)
        }
        return out
    }
}

/// The rows of choices; picking one re-runs the tool on the same input with that choice and hands back the new result.
struct ResultLooksRow: View {
    let chain: Chain
    let input: ChainPayload
    let text: String?
    let onResult: (ChainPayload, Chain) -> Void

    @State private var picked: [String: String] = [:]
    @State private var busy: String?
    @State private var started = Date()
    @State private var note: String?

    var body: some View {
        let groups = ResultLooks.groups(chain, text: text)
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                ForEach(groups) { g in
                    let current = picked[g.id] ?? chain.steps[g.step].settings[g.key].flatMap { $0.isEmpty ? nil : $0 } ?? g.fallback
                    Text(L(g.title)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    HandyFlow(spacing: 8) {
                        ForEach(g.options, id: \.id) { o in
                            Button { choose(g, o.id) } label: {
                                HStack(spacing: 4) {
                                    if busy == "\(g.id)=\(o.id)" { ProgressView().controlSize(.mini) }
                                    Text(g.key == "voice" ? o.name : L(o.name)).font(HandyFont.caption).lineLimit(1)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(current == o.id ? HandyColor.accent : HandyColor.surface, in: Capsule())
                                .foregroundStyle(current == o.id ? Color.white : HandyColor.textPrimary)
                            }.buttonStyle(.plain).disabled(busy != nil)
                            .accessibilityIdentifier("look-\(g.key)-\(o.id)")
                        }
                    }
                }
                if busy != nil {
                    // A video look takes a while: say it's working and for how long, never a bare spinner.
                    TimelineView(.periodic(from: started, by: 1)) { t in
                        Text("\(L("Making it…")) \(Int(t.date.timeIntervalSince(started))) s")
                            .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                }
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            .cardStyle(padding: HandySpacing.s12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("result-looks")
        }
    }

    private func choose(_ g: ResultLooks.Group, _ id: String) {
        let current = picked[g.id] ?? chain.steps[g.step].settings[g.key] ?? g.fallback
        guard id != current, busy == nil else { return }
        var next = chain
        next.steps[g.step].settings[g.key] = id
        // Choices made earlier on this result stay.
        for other in ResultLooks.groups(chain, text: text) where other.id != g.id {
            if let v = picked[other.id] { next.steps[other.step].settings[other.key] = v }
        }
        busy = "\(g.id)=\(id)"; started = Date(); note = nil
        let input = input
        Task {
            let rep = await ChainRunner.runReport(next, input: input)
            await MainActor.run {
                busy = nil
                if let p = rep.result { picked[g.id] = id; onResult(p, next) }
                else { note = L("That one couldn't be made from this. The result above is unchanged.") }
            }
        }
    }
}

/// Before and after: swipe, fade or side by side, remade from the same two photos.
struct RevealLooksRow: View {
    let before: UIImage
    let after: UIImage
    let name: String
    let onResult: (URL) -> Void
    @State private var current = "swipe"
    @State private var busy: String?
    @State private var started = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("Try another reveal")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            HandyFlow(spacing: 8) {
                ForEach(ChainText.revealStyles, id: \.id) { o in
                    Button { choose(o.id) } label: {
                        HStack(spacing: 4) {
                            if busy == o.id { ProgressView().controlSize(.mini) }
                            Text(L(o.name)).font(HandyFont.caption).lineLimit(1)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(current == o.id ? HandyColor.accent : HandyColor.surface, in: Capsule())
                        .foregroundStyle(current == o.id ? Color.white : HandyColor.textPrimary)
                    }.buttonStyle(.plain).disabled(busy != nil)
                    .accessibilityIdentifier("look-reveal-\(o.id)")
                }
            }
            if busy != nil {
                TimelineView(.periodic(from: started, by: 1)) { t in
                    Text("\(L("Making it…")) \(Int(t.date.timeIntervalSince(started))) s").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityIdentifier("reveal-looks")
    }

    private func choose(_ id: String) {
        guard id != current, busy == nil else { return }
        busy = id; started = Date()
        let b = before, a = after, file = ChainName.file(pattern: nil, tool: name, ext: "mp4")
        Task {
            let data = await ChainMotion.revealVideo(before: b, after: a, style: id)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(String(UUID().uuidString.prefix(6)) + "-" + file)
            let ok = data.map { (try? $0.write(to: url)) != nil } ?? false
            await MainActor.run {
                busy = nil
                if ok { current = id; onResult(url) }
            }
        }
    }
}

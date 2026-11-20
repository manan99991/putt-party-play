import SwiftUI
import AVFoundation

/// The finish for words — a summary, a translation, tidied or rewritten text, notes from a voice memo, a video's
/// transcript, where you are — the same for every ready-made text tool and any built tool ending in one of those
/// steps: the words to read and select, how much shorter (or what language) against the original, the original one
/// tap away, then Copy, Share, hear it read, and a map link opened in Maps when there is one.
struct TextFinishCard: View {
    let text: String
    var source: String?
    let block: Block

    @State private var showSource = false
    @StateObject private var voice = TextVoice()

    private var title: String {
        switch block {
        case .summarize: return "Summary"
        case .translate: return "Translation"
        case .rewrite: return "Rewritten"
        case .cleanText: return text.contains("maps.google.com") || text.contains("maps.apple.com") ? "Where you are" : "Tidied"
        case .speechText: return "What was said"
        default: return "Text"
        }
    }
    static func words(_ s: String) -> Int { s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count }
    private var mapURL: URL? {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
            .first { $0.hasPrefix("https://maps.") || $0.hasPrefix("http://maps.") }.flatMap(URL.init(string:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack {
                Label(L(title), systemImage: "text.alignleft").font(HandyFont.bodyStrong)
                Spacer()
                Text("\(Self.words(text)) \(L("words"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            ScrollView {
                Text(text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 340).scrollBounceBehavior(.basedOnSize)

            if let s = source?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty, s != text {
                let a = Self.words(s), b = Self.words(text)
                if block == .summarize, a > b {
                    Text("\(L("From")) \(a) \(L("words to")) \(b) — \(Int((1 - Double(b) / Double(max(1, a))) * 100))% \(L("shorter"))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                        .accessibilityIdentifier("text-shorter")
                }
                DisclosureGroup(isExpanded: $showSource) {
                    ScrollView { Text(s).font(HandyFont.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 220)
                } label: { Text(L("The original")).font(HandyFont.caption) }
            }

            if let m = mapURL {
                Link(destination: m) { Label(L("Open in Maps"), systemImage: "map").frame(maxWidth: .infinity) }.primaryButton()
            }
            HStack(spacing: HandySpacing.s8) {
                CopyButton(text: text)
                ShareLink(item: text) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
            Button { voice.toggle(text) } label: {
                Label(voice.speaking ? L("Stop") : L("Read it to me"), systemImage: voice.speaking ? "stop.fill" : "speaker.wave.2.fill").frame(maxWidth: .infinity)
            }.textButton()
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("text-finish")
        .onDisappear { voice.stop() }
    }
}

/// Reads text aloud with the phone's voice in the text's own language, and says when it stops.
final class TextVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var speaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func toggle(_ text: String) {
        if speaking { stop(); return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        let u = AVSpeechUtterance(string: String(text.prefix(20_000)))
        if let lang = NLLanguageGuess.language(of: text) { u.voice = AVSpeechSynthesisVoice(language: lang) }
        synth.speak(u); speaking = true
    }
    func stop() { synth.stopSpeaking(at: .immediate); speaking = false }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { DispatchQueue.main.async { self.speaking = false } }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { DispatchQueue.main.async { self.speaking = false } }
}

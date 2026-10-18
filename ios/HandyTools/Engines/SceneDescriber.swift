import UIKit
import Vision
import AVFoundation

/// Perception for Scene Describer: what's in frame (scene labels, people, animals, readable text),
/// turned into one spoken sentence. Vision runs on every iPhone; when on-device Apple Intelligence is
/// present the sentence is polished by the language model, otherwise a rule-based composer speaks.
enum SceneDescriber {
    struct Perception: Equatable {
        var labels: [(String, Double)] = []   // identifier, confidence
        var people = 0
        var animals: [String] = []
        var text: [String] = []
        static func == (a: Perception, b: Perception) -> Bool { a.people == b.people && a.animals == b.animals && a.text == b.text && a.labels.map(\.0) == b.labels.map(\.0) }
    }

    static func perceive(_ image: UIImage) -> Perception {
        guard let cg = image.normalizedUp().cgImage else { return Perception() }
        let classify = VNClassifyImageRequest()
        let humans = VNDetectHumanRectanglesRequest(); humans.upperBodyOnly = true
        let animals = VNRecognizeAnimalsRequest()
        let text = VNRecognizeTextRequest(); text.recognitionLevel = .fast; text.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([classify, humans, animals, text])
        var p = Perception()
        p.labels = (classify.results ?? []).filter { $0.confidence > 0.25 }.prefix(8).map { ($0.identifier.replacingOccurrences(of: "_", with: " "), Double($0.confidence)) }
        p.people = humans.results?.count ?? 0
        p.animals = (animals.results ?? []).compactMap { $0.labels.first?.identifier }
        p.text = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }.filter { $0.count > 1 }
        return p
    }

    /// Plain-language sentence from perception — short, concrete, no hedging words.
    static func compose(_ p: Perception) -> String {
        var parts: [String] = []
        let scene = p.labels.first { !generic.contains($0.0) }?.0
        if let scene { parts.append("Looks like \(article(scene)) \(scene).") }
        else if let any = p.labels.first?.0 { parts.append("I see \(any).") }
        if p.people == 1 { parts.append("One person in view.") } else if p.people > 1 { parts.append("\(p.people) people in view.") }
        if !p.animals.isEmpty {
            let counts = Dictionary(grouping: p.animals, by: { $0 }).map { "\($0.value.count == 1 ? "a" : "\($0.value.count)") \($0.key)\($0.value.count == 1 ? "" : "s")" }
            parts.append("Also " + counts.joined(separator: " and ") + ".")
        }
        let others = p.labels.dropFirst().map(\.0).filter { !generic.contains($0) && $0 != scene }.prefix(3)
        if !others.isEmpty { parts.append("Nearby: " + others.joined(separator: ", ") + ".") }
        if !p.text.isEmpty {
            let joined = p.text.prefix(4).joined(separator: ", ")
            parts.append("Text reads: \(joined).")
        }
        if parts.isEmpty { return "Nothing I can name — try pointing at something with more light." }
        return parts.joined(separator: " ")
    }

    private static let generic: Set<String> = ["indoor", "outdoor", "structure", "people", "adult", "person", "text", "document", "object", "material", "equipment", "furniture", "no person", "art", "machine", "vehicle", "food", "animal", "plant", "clothing", "sky", "wall", "floor", "ceiling", "room"]
    private static func article(_ s: String) -> String { ["a", "e", "i", "o", "u"].contains(String(s.prefix(1)).lowercased()) ? "an" : "a" }

    /// With Apple Intelligence: rewrite as one natural, helpful sentence for someone who can't see the scene.
    static func polish(_ p: Perception, fallback: String) async -> String {
        guard AIEngine.isAvailable else { return fallback }
        let facts = """
        scene labels (confidence): \(p.labels.map { "\($0.0) \(Int($0.1 * 100))%" }.joined(separator: ", "))
        people: \(p.people); animals: \(p.animals.joined(separator: ", ")); text: \(p.text.prefix(6).joined(separator: " | "))
        """
        let out = try? await AIEngine.run(instructions: "You narrate a phone camera view for a blind or low-vision person. From the detections, write ONE or TWO short plain sentences: what the place or object is, people or animals, and any text worth reading. Be concrete and calm. Never mention confidence numbers, never guess beyond the facts, never give safety or navigation advice.", prompt: facts)
        return out?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? out! : fallback
    }
}

/// Speaks sentences, interrupting the previous one, with a rate the user can set.
@MainActor final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var speaking = false
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func say(_ s: String) {
        guard !s.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers]); try? AVAudioSession.sharedInstance().setActive(true)
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: s); u.rate = rate
        synth.speak(u); speaking = true
    }
    func stop() { synth.stopSpeaking(at: .immediate); speaking = false }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { Task { @MainActor in self.speaking = false } }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { Task { @MainActor in self.speaking = false } }
}

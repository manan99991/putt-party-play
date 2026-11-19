import Foundation

/// The parts of Flashlight+ that aren't the LED itself: Morse speeds, the emergency siren sound,
/// and the pattern a shortcut (Action button, Back Tap, Siri) asks for. Pure and unit-tested.
enum TorchExtras {
    /// Morse speeds as the length of one dot. Slow is easy to read by eye from far away.
    static let morseSpeeds: [(label: String, unitMs: Int)] = [("Slow", 280), ("Normal", 180), ("Fast", 110)]

    /// How long one pass of a message takes at a speed — shown so people know what to expect.
    @MainActor static func morseSeconds(_ text: String, unitMs: Int) -> Double {
        let code = Torch.encodeMorse(text)
        guard !code.isEmpty else { return 0 }
        var units = 0
        for ch in code {
            switch ch {
            case ".": units += 2
            case "-": units += 4
            case " ": units += 2
            case "/": units += 4
            default: break
            }
        }
        units += 7
        return Double(units * unitMs) / 1000
    }

    /// A rising-and-falling siren as a 16-bit mono WAV, made on the phone (no sound file shipped).
    /// One sweep low → high → low per `sweep` seconds; loops cleanly because it starts and ends at the low note.
    static func sirenWAV(seconds: Double = 2, sampleRate: Int = 22050, low: Double = 650, high: Double = 1550, sweep: Double = 1) -> Data {
        let n = max(1, Int(seconds * Double(sampleRate)))
        var samples = [Int16](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / Double(sampleRate)
            let pos = (t.truncatingRemainder(dividingBy: sweep)) / sweep          // 0…1 within a sweep
            let tri = pos < 0.5 ? pos * 2 : (1 - pos) * 2                          // 0→1→0
            let f = low + (high - low) * tri
            phase += 2 * Double.pi * f / Double(sampleRate)
            if phase > 2 * Double.pi { phase -= 2 * Double.pi }
            // A touch of square-ish edge makes it cut through noise like a real alarm.
            let v = max(-1, min(1, sin(phase) * 1.4))
            samples[i] = Int16(v * 0.9 * Double(Int16.max))
        }
        var d = Data(ChainText.wavHeader(sampleRate: sampleRate, channels: 1, dataBytes: n * 2))
        samples.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }

    // MARK: - Asked for by a shortcut

    static let pendingKey = "light.pending"
    /// What a shortcut can ask for. "emergency" opens the full-screen emergency light.
    static let shortcutPatterns = ["steady", "sos", "strobeMed", "emergency"]

    static func setPending(_ pattern: String) {
        UserDefaults.standard.set(pattern, forKey: pendingKey)
    }
    /// Read once: a shortcut's request is used when Flashlight+ opens, then forgotten.
    static func takePending() -> String? {
        let v = UserDefaults.standard.string(forKey: pendingKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return v.flatMap { shortcutPatterns.contains($0) ? $0 : nil }
    }
}

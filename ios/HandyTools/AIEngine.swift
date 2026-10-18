import Foundation
import Vision
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wraps Apple's on-device Foundation Models (iOS 26+, Apple-silicon iPhones). Everything runs
/// locally — no network, no server, no API bill, and nothing leaves the phone. When the model
/// isn't present (older phone / OS), `isAvailable` is false and tools show a graceful fallback.
enum AIEngine {

    enum AIError: LocalizedError {
        case unavailable
        case empty
        var errorDescription: String? {
            switch self {
            case .unavailable: return "On-device AI isn't available on this iPhone."
            case .empty: return "There was nothing to work with."
            }
        }
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Why the model can't run, in plain language — drives the fallback card's explanation.
    static var availabilityReason: String {
        isAvailable ? "" : "On-device AI needs an iPhone 15 Pro or newer with Apple Intelligence turned on. It's free, runs entirely on your phone, and nothing is uploaded."
    }

    /// One-shot generation. `instructions` sets the role; `prompt` is the user content.
    static func run(instructions: String, prompt: String) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.empty }
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable {
            let session = LanguageModelSession { instructions }
            let response = try await session.respond(to: trimmed)
            return response.content
        }
        #endif
        throw AIError.unavailable
    }

    // MARK: - Vision helpers (work on every phone, no Apple Intelligence needed)

    /// Pull all readable text out of an image (printed or handwritten).
    static func recognizeText(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async { try? handler.perform([req]) }
        }
    }

    /// Best-guess labels for what's in a photo, most confident first.
    static func classify(_ image: UIImage, top: Int = 5) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let req = VNClassifyImageRequest { request, _ in
                let labels = (request.results as? [VNClassificationObservation])?
                    .filter { $0.confidence > 0.1 }
                    .prefix(top)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") } ?? []
                cont.resume(returning: Array(labels))
            }
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async { try? handler.perform([req]) }
        }
    }
}

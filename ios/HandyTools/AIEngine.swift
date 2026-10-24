import Foundation
import Vision
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

extension UIImage {
    /// Redraws the image so its pixels are upright (orientation .up), fixing EXIF-rotated photos
    /// before they go to Vision — otherwise portrait shots come out sideways.
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Wraps Apple's on-device Foundation Models (iOS 26+, Apple-silicon iPhones). Everything runs
/// locally — no network, no server, no API bill, and nothing leaves the phone. When the model
/// isn't present (older phone / OS), `isAvailable` is false and tools show a graceful fallback.
enum AIEngine {

    enum AIError: LocalizedError {
        case unavailable
        case empty
        case timeout
        var errorDescription: String? {
            switch self {
            case .unavailable: return "On-device AI isn't available on this iPhone."
            case .empty: return "There was nothing to work with."
            case .timeout: return "On-device AI took too long and was stopped."
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

    /// One-shot generation. `instructions` sets the role; `prompt` is the user content. Bounded by a
    /// hard timeout so a wedged on-device model can never hang a tool's spinner — every AI tool falls
    /// back to its built-in engine (or shows a clean error) instead of freezing.
    static func run(instructions: String, prompt: String, timeout: TimeInterval = 60) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.empty }
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable {
            return try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let session = LanguageModelSession { instructions }
                    return try await session.respond(to: trimmed).content
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw AIError.timeout
                }
                defer { group.cancelAll() }
                guard let result = try await group.next() else { throw AIError.timeout }
                return result
            }
        }
        #endif
        throw AIError.unavailable
    }

    // MARK: - Vision helpers (work on every phone, no Apple Intelligence needed)

    /// Pull all readable text out of an image (printed or handwritten).
    static func recognizeText(_ image: UIImage) async -> String {
        guard let cg = image.normalizedUp().cgImage else { return "" }
        nonisolated(unsafe) let cgSafe = cg
        return await withCheckedContinuation { cont in
            nonisolated(unsafe) let handler = VNImageRequestHandler(cgImage: cgSafe, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async {
                // Vision calls the completion handler synchronously inside perform(), on this thread.
                // If perform() throws, it is NOT called — so resume once from here as a fallback,
                // guarded so a successful run never double-resumes (which would crash).
                var resumed = false
                let req = VNRecognizeTextRequest { request, _ in
                    let lines = (request.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string } ?? []
                    resumed = true
                    cont.resume(returning: lines.joined(separator: "\n"))
                }
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = true
                do { try handler.perform([req]) } catch { }
                if !resumed { cont.resume(returning: "") }
            }
        }
    }

    /// Best-guess labels for what's in a photo, most confident first.
    static func classify(_ image: UIImage, top: Int = 5) async -> [String] {
        guard let cg = image.normalizedUp().cgImage else { return [] }
        nonisolated(unsafe) let cgSafe = cg
        return await withCheckedContinuation { cont in
            nonisolated(unsafe) let handler = VNImageRequestHandler(cgImage: cgSafe, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async {
                var resumed = false
                let req = VNClassifyImageRequest { request, _ in
                    let labels = (request.results as? [VNClassificationObservation])?
                        .filter { $0.confidence > 0.1 }
                        .prefix(top)
                        .map { $0.identifier.replacingOccurrences(of: "_", with: " ") } ?? []
                    resumed = true
                    cont.resume(returning: Array(labels))
                }
                do { try handler.perform([req]) } catch { }
                if !resumed { cont.resume(returning: []) }
            }
        }
    }
}

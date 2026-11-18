import Foundation
import AVFoundation

/// Join several clips into one, and change speed without the chipmunk effect — on device. Both build an
/// AVMutableComposition and export it as M4A, the same proven path the ringtone maker uses. Sources may
/// be audio files or videos (their sound is used).
enum AudioMix {
    enum Failure: Error, Equatable {
        case noAudio, tooFew, cannotWrite, timedOut
        var message: String {
            switch self {
            case .noAudio: return "One of those files has no sound Tenzy can read."
            case .tooFew: return "Add at least two clips to join."
            case .cannotWrite: return "This phone couldn't save the audio — try again."
            case .timedOut: return "That took too long and was stopped."
            }
        }
    }

    static let speeds: [Double] = [0.5, 0.75, 1.25, 1.5, 2.0]

    /// Join `sources` end to end, with `gap` seconds of silence between clips.
    static func merge(_ sources: [URL], gap: Double = 0,
                      progress: ((Double) -> Void)? = nil) async -> Result<URL, Failure> {
        guard sources.count >= 2 else { return .failure(.tooFew) }
        let comp = AVMutableComposition()
        guard let dst = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return .failure(.cannotWrite)
        }
        var cursor = CMTime.zero
        let pause = CMTime(seconds: max(0, gap), preferredTimescale: 600)
        for (i, url) in sources.enumerated() {
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
                  let range = try? await track.load(.timeRange), range.duration.seconds > 0 else {
                return .failure(.noAudio)
            }
            do { try dst.insertTimeRange(range, of: track, at: cursor) } catch { return .failure(.cannotWrite) }
            cursor = cursor + range.duration
            if i < sources.count - 1, pause.seconds > 0 { cursor = cursor + pause }
        }
        return await export(comp, progress: progress)
    }

    /// Play `src` at `rate` (0.5 = half speed, 2 = double) while keeping the voice's pitch natural.
    static func speed(_ src: URL, rate: Double,
                      progress: ((Double) -> Void)? = nil) async -> Result<URL, Failure> {
        let r = min(4, max(0.25, rate))
        let asset = AVURLAsset(url: src)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let range = try? await track.load(.timeRange), range.duration.seconds > 0 else {
            return .failure(.noAudio)
        }
        let comp = AVMutableComposition()
        guard let dst = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return .failure(.cannotWrite)
        }
        do { try dst.insertTimeRange(range, of: track, at: .zero) } catch { return .failure(.cannotWrite) }
        let newDuration = CMTime(seconds: range.duration.seconds / r, preferredTimescale: 600)
        dst.scaleTimeRange(CMTimeRange(start: .zero, duration: range.duration), toDuration: newDuration)
        return await export(comp, progress: progress)
    }

    /// Export a composition as M4A with pitch-preserving time stretching, reporting progress and never
    /// hanging (a hard timeout cancels it).
    private static func export(_ asset: AVAsset, timeout: Double = 600,
                               progress: ((Double) -> Void)?) async -> Result<URL, Failure> {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return .failure(.cannotWrite)
        }
        let out = VideoEngine.tempURL("m4a")
        session.outputURL = out
        session.outputFileType = .m4a
        session.audioTimePitchAlgorithm = .spectral
        let outcome: Int = await withTaskGroup(of: Int.self) { group -> Int in
            group.addTask { await session.export(); return session.status == .completed ? 1 : 0 }
            group.addTask {
                while !Task.isCancelled {
                    progress?(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                return -2
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if Task.isCancelled { return -2 }
                session.cancelExport(); return -1
            }
            var result = -2
            while let r = await group.next() {
                if r != -2 { result = r; break }
            }
            group.cancelAll()
            return result
        }
        if outcome == 1 { progress?(1); return .success(out) }
        try? FileManager.default.removeItem(at: out)
        return .failure(outcome == -1 ? .timedOut : .cannotWrite)
    }
}

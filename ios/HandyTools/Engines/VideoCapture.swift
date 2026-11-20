import Foundation
import AVFoundation
import CoreImage
import Photos

/// Pro Camera's video mode, the parts that aren't the live camera:
/// - `VideoRecorder` turns the camera's own frames (plus the microphone) into a movie file, so the scene
///   settings, focus and exposure you see are exactly what's filmed.
/// - `VideoScene` is the "best for…" set-up for each kind of filming (frame rate, shutter, steadiness).
/// - `FilmingCoach` turns what the camera sees into one plain tip at a time.
/// All of it is tested without a camera: the recorder is fed made-up frames and sound in the unit tests.

final class VideoRecorder: @unchecked Sendable {
    let url: URL
    private let fps: Int
    private let realtime: Bool
    private let withAudio: Bool
    private let lock = NSLock()
    private var writer: AVAssetWriter?
    private var videoIn: AVAssetWriterInput?
    private var audioIn: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var started = false
    private var finished = false
    private(set) var frames = 0
    private(set) var audioBuffers = 0
    private(set) var firstTime: CMTime = .invalid
    private(set) var lastTime: CMTime = .invalid

    init(url: URL, fps: Int = 30, realtime: Bool = true, withAudio: Bool = true) {
        self.url = url; self.fps = max(1, fps); self.realtime = realtime; self.withAudio = withAudio
        try? FileManager.default.removeItem(at: url)
    }

    /// Settings for the video track, sized from the first frame (frames arrive already turned upright).
    static func videoSettings(width: Int, height: Int, fps: Int) -> [String: Any] {
        // H.264 plays everywhere — every phone, TV, website and Windows PC — so the clip never needs converting.
        // ~0.2 bits per pixel per frame: 1080p30 at ~12 Mbit/s, close to the stock camera.
        let bitrate = Int(Double(width * height * fps) * 0.2)
        return [AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width, AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: max(2_000_000, bitrate),
                                                  AVVideoExpectedSourceFrameRateKey: fps,
                                                  AVVideoMaxKeyFrameIntervalKey: fps * 2]]
    }

    static let audioSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1,
                                               AVSampleRateKey: 44_100, AVEncoderBitRateKey: 128_000]

    private func setUp(width: Int, height: Int, at time: CMTime) -> Bool {
        guard let w = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return false }
        let v = AVAssetWriterInput(mediaType: .video, outputSettings: Self.videoSettings(width: width, height: height, fps: fps))
        v.expectsMediaDataInRealTime = realtime
        let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: v, sourcePixelBufferAttributes: nil)
        guard w.canAdd(v) else { return false }
        w.add(v)
        let a = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.audioSettings)
        a.expectsMediaDataInRealTime = realtime
        if withAudio, w.canAdd(a) { w.add(a); audioIn = a }
        guard w.startWriting() else { return false }
        w.startSession(atSourceTime: time)
        writer = w; videoIn = v; adaptor = ad; started = true; firstTime = time
        return true
    }

    /// Wait for an input when not live (tests, imports); live frames that arrive while the encoder is busy are dropped.
    private func ready(_ input: AVAssetWriterInput) -> Bool {
        if input.isReadyForMoreMediaData { return true }
        guard !realtime else { return false }
        // Not live: never drop a frame because the encoder is busy — wait for it (up to 10 s on a slow, loaded phone).
        for _ in 0..<2000 { usleep(5_000); if input.isReadyForMoreMediaData { return true } }
        return false
    }

    @discardableResult
    func appendVideo(_ pb: CVPixelBuffer, at time: CMTime) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !finished, time.isValid else { return false }
        if !started, !setUp(width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb), at: time) { return false }
        guard let v = videoIn, let ad = adaptor, writer?.status == .writing else { return false }
        // Frames must move forward in time; a repeated or earlier one is skipped, never written.
        if lastTime.isValid, CMTimeCompare(time, lastTime) <= 0 { return false }
        guard ready(v), ad.append(pb, withPresentationTime: time) else { return false }
        frames += 1; lastTime = time
        return true
    }

    @discardableResult
    func appendAudio(_ sample: CMSampleBuffer) -> Bool {
        lock.lock(); defer { lock.unlock() }
        // Sound that comes before the first frame is left out, so the movie never starts on a black frame.
        guard started, !finished, let a = audioIn, writer?.status == .writing,
              CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sample), firstTime) >= 0, ready(a), a.append(sample) else { return false }
        audioBuffers += 1
        return true
    }

    var seconds: Double {
        lock.lock(); defer { lock.unlock() }
        guard firstTime.isValid, lastTime.isValid else { return 0 }
        return CMTimeSubtract(lastTime, firstTime).seconds
    }

    /// Close the file. Nil when nothing was filmed or the encoder failed.
    func finish() async -> URL? {
        lock.lock()
        guard !finished, let w = writer, started, frames > 0 else { finished = true; lock.unlock(); return nil }
        finished = true
        videoIn?.markAsFinished(); audioIn?.markAsFinished()
        if lastTime.isValid { w.endSession(atSourceTime: CMTimeAdd(lastTime, CMTime(value: 1, timescale: CMTimeScale(fps)))) }
        lock.unlock()
        await w.finishWriting()
        return w.status == .completed ? url : nil
    }

    func cancel() {
        lock.lock(); finished = true; let w = writer; lock.unlock()
        w?.cancelWriting()
        try? FileManager.default.removeItem(at: url)
    }

    /// A short burst of mono 16-bit sound as a sample buffer — how the tests stand in for the microphone.
    static func audioBuffer(frequency: Double, frames: Int, sampleRate: Double = 44_100, at time: CMTime) -> CMSampleBuffer? {
        var asbd = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var fmt: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &fmt) == noErr, let fmt else { return nil }
        let bytes = frames * 2
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes, blockAllocator: nil, customBlockSource: nil,
                                                 offsetToData: 0, dataLength: bytes, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block) == noErr, let block else { return nil }
        var pcm = [Int16](repeating: 0, count: frames)
        for i in 0..<frames { pcm[i] = Int16(sin(2 * .pi * frequency * Double(i) / sampleRate) * 12_000) }
        _ = pcm.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes) }
        var out: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: fmt, sampleCount: frames,
                                                                    presentationTimeStamp: time, packetDescriptions: nil, sampleBufferOut: &out) == noErr else { return nil }
        return out
    }

    /// Save a finished movie to Photos.
    static func saveToPhotos(_ url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }
            return true
        } catch { return false }
    }
}

/// "Best for…" set-ups for filming. Each is a frame rate, the slowest shutter auto-exposure may use, how
/// steady to hold the picture, and one line on why.
enum VideoScene: String, CaseIterable, Identifiable {
    case everyday, action, night, interview, vlog, cinematic
    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyday: "Everyday"
        case .action: "Sports & kids"
        case .night: "Low light"
        case .interview: "Interview"
        case .vlog: "Walk & talk"
        case .cinematic: "Cinematic"
        }
    }
    var icon: String {
        switch self {
        case .everyday: "video"
        case .action: "figure.run"
        case .night: "moon.stars"
        case .interview: "person.2.wave.2"
        case .vlog: "figure.walk"
        case .cinematic: "film"
        }
    }
    var fps: Int {
        switch self {
        case .action: 60
        case .cinematic: 24
        default: 30
        }
    }
    /// Longest shutter auto-exposure may pick. Fast for sport (crisp motion), 1/48 for cinema's natural blur
    /// (the 180° rule), and the full frame time in low light so it gathers as much as it can.
    var maxShutter: Double {
        switch self {
        case .action: 1.0 / 250
        case .cinematic: 1.0 / 48
        case .night: 1.0 / Double(fps)
        default: 1.0 / 60
        }
    }
    var stabilization: AVCaptureVideoStabilizationMode {
        switch self {
        case .vlog, .action: .cinematicExtended
        case .cinematic, .interview: .cinematic
        default: .auto
        }
    }
    var why: String {
        switch self {
        case .everyday: "30 frames a second, steadied, exposure and focus follow what's in the middle."
        case .action: "60 frames a second and a fast shutter, so running kids and a ball stay sharp — and slow-mo looks smooth."
        case .night: "Lets each frame gather as much light as it can and turns on low-light boost. Keep the phone still."
        case .interview: "Focus and exposure stay on the face in the middle; steady and quiet. Get close to the person talking."
        case .vlog: "Strongest steadying for walking. Hold the phone at chest height and walk smoothly."
        case .cinematic: "24 frames a second with a 1/48 shutter — the film look, with natural motion blur."
        }
    }
}

/// One tip at a time while filming, most important first. Pure, so every tip is tested.
enum FilmingCoach {
    struct Reading: Equatable {
        var brightness: Double          // mean luma 0…1
        var clipped: Double             // share of the frame blown to white 0…1
        var upright: Bool               // phone held vertically
        var shake: Double               // rotation rate, rad/s
        var recording: Bool
        var seconds: Double
        var scene: VideoScene
    }

    static func tip(_ r: Reading) -> String? {
        if r.shake > 1.6 { return r.scene == .vlog ? "Slow down — smooth steps keep it watchable." : "Hold steady — move the phone slower." }
        if r.brightness < 0.12 { return r.scene == .night ? "Very dark — rest the phone on something steady." : "Too dark — find more light or switch to Low light." }
        if r.clipped > 0.12 { return "The bright part is blown out — tap it to expose for it." }
        if r.upright, !r.recording, r.scene != .vlog { return "Turn the phone sideways for a video that fills TVs and YouTube." }
        if r.recording, r.seconds > 0, r.seconds < 3 { return "Keep going — clips under 3 seconds feel too short." }
        if r.scene == .interview, !r.recording { return "Get close: the mic is on the phone, so 1 metre from the speaker sounds best." }
        return nil
    }

    static func timeText(_ s: Double) -> String {
        let t = max(0, Int(s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

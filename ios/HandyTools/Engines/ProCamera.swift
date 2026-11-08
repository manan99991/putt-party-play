import UIKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import UniformTypeIdentifiers

/// Manual camera: locked ISO / shutter / focus / white balance, RAW (DNG) capture, focus peaking,
/// zebras, a live histogram and frame-averaged long exposures — the controls the stock app hides.
@MainActor final class ProCameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published var latest: CIImage?
    @Published var authorized = true
    @Published var ranges = Ranges()
    @Published var current = Current()
    @Published var rawSupported = false
    @Published var saving = false
    @Published var lastSaved: UIImage?
    @Published var lastMessage = ""
    @Published var accumulating = false
    @Published var accumulated = 0

    struct Ranges { var minISO: Float = 50, maxISO: Float = 1600; var minShutter = 1.0 / 8000, maxShutter = 1.0 / 3; var minTemp: Float = 2500, maxTemp: Float = 8000 }
    struct Current { var iso: Float = 100; var shutter = 1.0 / 60; var lens: Float = 0.5; var temp: Float = 5000; var autoExposure = true; var autoFocus = true; var autoWB = true; var ev: Float = 0 }

    let session = AVCaptureSession()
    private let video = AVCaptureVideoDataOutput()
    private let photo = AVCapturePhotoOutput()
    private(set) var device: AVCaptureDevice?
    private let queue = DispatchQueue(label: "tenzy.procam", qos: .userInteractive)
    private var continuation: CheckedContinuation<(Data?, Data?), Never>?
    nonisolated(unsafe) private var accumulator: CIImage?
    nonisolated(unsafe) private var accCount = 0
    nonisolated(unsafe) private var accTarget = 0
    private let ctx = CIContext()
    // Long-exposure accumulation lives in two ping-pong half-float buffers we own. Keeping a lazy CIImage
    // chain instead pinned every camera frame buffer, the pool ran dry after ~6 frames and the camera
    // stopped delivering (the "frozen at 6/120" bug), and the chain nested one level per frame.
    nonisolated(unsafe) private let accCtx = CIContext()
    nonisolated(unsafe) private var accBuffers: [CVPixelBuffer] = []
    nonisolated(unsafe) private var accIndex = 0
    private var angle: CGFloat = 90          // rotation currently applied to the frames (for tap-to-focus mapping)
    private var subjectObs: NSObjectProtocol?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObs: NSKeyValueObservation?

    func start() {
        nonisolated(unsafe) let s = session
        if !session.inputs.isEmpty { if !session.isRunning { DispatchQueue.global().async { s.startRunning() } }; return }
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else { return }
        Permission.camera { [weak self] ok in Task { @MainActor in self?.authorized = ok } }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else { session.commitConfiguration(); return }
        device = dev
        session.addInput(input)
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(video) { session.addOutput(video) }
        if session.canAddOutput(photo) { session.addOutput(photo) }
        photo.maxPhotoQualityPrioritization = .quality
        if let c = video.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        if let c = photo.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        session.commitConfiguration()
        // Follow how the phone is actually held: landscape in -> landscape preview and landscape photos out.
        let rc = AVCaptureDevice.RotationCoordinator(device: dev, previewLayer: nil)
        rotation = rc
        applyRotation(rc.videoRotationAngleForHorizonLevelCapture)
        rotationObs = rc.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, change in
            guard let a = change.newValue else { return }
            Task { @MainActor in self?.applyRotation(a) }
        }
        // Sanitize everything that feeds a Slider range or an Int(): a device can report 0/NaN
        // durations or inverted bounds before streaming, and SwiftUI traps on an invalid range.
        let f = dev.activeFormat
        let loISO = max(1, f.minISO)
        let hiISO = max(loISO + 1, f.maxISO)
        let minDur = f.minExposureDuration.seconds, maxDur = f.maxExposureDuration.seconds
        let loSh = max(1.0 / 8000, minDur.isFinite && minDur > 0 ? minDur : 1.0 / 8000)
        let hiSh = max(loSh * 2, min(1.0 / 2, maxDur.isFinite && maxDur > loSh ? maxDur : 1.0 / 2))
        ranges = Ranges(minISO: loISO, maxISO: hiISO, minShutter: loSh, maxShutter: hiSh, minTemp: 2500, maxTemp: 8000)
        rawSupported = !photo.availableRawPhotoPixelFormatTypes.isEmpty
        let isoNow = dev.iso.isFinite ? dev.iso : loISO
        current.iso = max(loISO, min(isoNow, hiISO))
        let shNow = dev.exposureDuration.seconds
        current.shutter = shNow.isFinite && shNow > 0 ? min(max(shNow, loSh), hiSh) : loSh
        // Always start fully automatic: continuous focus, exposure and white balance.
        resetToAuto()
        subjectObs = NotificationCenter.default.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: dev, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refocusIfAuto() }
        }
        DispatchQueue.global().async { s.startRunning() }
    }

    /// Rotate the live frames and the photo output to match the phone. Held still during a long exposure.
    private func applyRotation(_ angle: CGFloat) {
        guard !accumulating else { return }
        self.angle = angle
        if let c = video.connection(with: .video), c.isVideoRotationAngleSupported(angle) { c.videoRotationAngle = angle }
        if let c = photo.connection(with: .video), c.isVideoRotationAngleSupported(angle) { c.videoRotationAngle = angle }
    }

    func stop() {
        nonisolated(unsafe) let s = session
        if session.isRunning { DispatchQueue.global().async { s.stopRunning() } }
    }

    // MARK: manual controls

    /// Back to fully automatic: continuous focus / exposure / white balance on the centre of the frame,
    /// the full shutter range, and the camera's own low-light boost. Every "best for…" look starts here,
    /// so a previous look can never leave the lens locked on the wrong distance (the blurry-preview bug).
    func resetToAuto() {
        current.autoExposure = true; current.autoFocus = true; current.autoWB = true; current.ev = 0
        guard let d = device else { return }
        try? d.lockForConfiguration()
        if d.isFocusPointOfInterestSupported { d.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
        if d.isFocusModeSupported(.continuousAutoFocus) { d.focusMode = .continuousAutoFocus }
        if d.isExposurePointOfInterestSupported { d.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) }
        if d.isExposureModeSupported(.continuousAutoExposure) { d.exposureMode = .continuousAutoExposure }
        if d.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { d.whiteBalanceMode = .continuousAutoWhiteBalance }
        d.setExposureTargetBias(0)
        d.activeMaxExposureDuration = d.activeFormat.maxExposureDuration
        if d.isLowLightBoostSupported { d.automaticallyEnablesLowLightBoostWhenAvailable = true }
        d.isSubjectAreaChangeMonitoringEnabled = true
        d.unlockForConfiguration()
    }

    /// Cap the auto-exposure shutter (e.g. 1/500 s to freeze motion) while keeping everything else automatic.
    func limitShutter(_ seconds: Double) {
        guard let d = device else { return }
        let f = d.activeFormat
        let lo = f.minExposureDuration.seconds, hi = f.maxExposureDuration.seconds
        guard lo.isFinite, hi.isFinite, hi > lo else { return }
        try? d.lockForConfiguration()
        d.activeMaxExposureDuration = CMTime(seconds: min(max(seconds, lo), hi), preferredTimescale: 1_000_000)
        d.unlockForConfiguration()
    }

    /// Tap-to-focus: `p` is a point in the displayed (already rotated) frame, 0…1 from the top-left.
    /// Focus and exposure follow that point, continuously, so the subject stays sharp.
    func focus(atFrame p: CGPoint) {
        guard let d = device, (0...1).contains(p.x), (0...1).contains(p.y) else { return }
        // The sensor's own coordinates are the un-rotated landscape frame; undo the rotation we applied.
        let q: CGPoint
        switch Int(angle.rounded()) % 360 {
        case 90:  q = CGPoint(x: p.y, y: 1 - p.x)
        case 180: q = CGPoint(x: 1 - p.x, y: 1 - p.y)
        case 270: q = CGPoint(x: 1 - p.y, y: p.x)
        default:  q = p
        }
        try? d.lockForConfiguration()
        if d.isFocusPointOfInterestSupported, d.isFocusModeSupported(.continuousAutoFocus) { d.focusPointOfInterest = q; d.focusMode = .continuousAutoFocus }
        if current.autoExposure, d.isExposurePointOfInterestSupported, d.isExposureModeSupported(.continuousAutoExposure) { d.exposurePointOfInterest = q; d.exposureMode = .continuousAutoExposure }
        d.unlockForConfiguration()
        current.autoFocus = true
    }

    /// When the scene changes and we're automatic, go back to centre-weighted continuous focus.
    private func refocusIfAuto() {
        guard current.autoFocus, current.autoExposure, !accumulating, let d = device else { return }
        try? d.lockForConfiguration()
        if d.isFocusPointOfInterestSupported { d.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
        if d.isFocusModeSupported(.continuousAutoFocus) { d.focusMode = .continuousAutoFocus }
        if d.isExposurePointOfInterestSupported { d.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) }
        if d.isExposureModeSupported(.continuousAutoExposure) { d.exposureMode = .continuousAutoExposure }
        d.unlockForConfiguration()
    }

    func applyExposure() {
        guard let d = device else { return }
        try? d.lockForConfiguration()
        if current.autoExposure {
            if d.isExposureModeSupported(.continuousAutoExposure) { d.exposureMode = .continuousAutoExposure }
            d.setExposureTargetBias(max(d.minExposureTargetBias, min(d.maxExposureTargetBias, current.ev)))
        } else if d.isExposureModeSupported(.custom) {
            let iso = max(ranges.minISO, min(ranges.maxISO, current.iso))
            let sh = max(ranges.minShutter, min(ranges.maxShutter, current.shutter))
            d.setExposureModeCustom(duration: CMTime(seconds: sh, preferredTimescale: 1_000_000), iso: iso)
        }
        d.unlockForConfiguration()
    }

    func applyFocus() {
        guard let d = device else { return }
        try? d.lockForConfiguration()
        if current.autoFocus { if d.isFocusModeSupported(.continuousAutoFocus) { d.focusMode = .continuousAutoFocus } }
        else if d.isLockingFocusWithCustomLensPositionSupported { d.setFocusModeLocked(lensPosition: max(0, min(1, current.lens))) }
        d.unlockForConfiguration()
    }

    func applyWhiteBalance() {
        guard let d = device else { return }
        try? d.lockForConfiguration()
        if current.autoWB { if d.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { d.whiteBalanceMode = .continuousAutoWhiteBalance } }
        else if d.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            var g = d.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: current.temp, tint: 0))
            let mx = d.maxWhiteBalanceGain
            g.redGain = max(1, min(mx, g.redGain)); g.greenGain = max(1, min(mx, g.greenGain)); g.blueGain = max(1, min(mx, g.blueGain))
            d.setWhiteBalanceModeLocked(with: g)
        }
        d.unlockForConfiguration()
    }

    /// Read back the auto values so sliders start where the camera is when the user switches to manual.
    func syncFromDevice() {
        guard let d = device else { return }
        current.iso = d.iso; current.shutter = d.exposureDuration.seconds; current.lens = d.lensPosition
        current.temp = max(ranges.minTemp, min(ranges.maxTemp, d.temperatureAndTintValues(for: d.deviceWhiteBalanceGains).temperature))
    }

    // MARK: capture

    /// Take a photo. Returns (processed HEIF/JPEG data, RAW DNG data if requested and available).
    func capture(raw: Bool) async -> (Data?, Data?) {
        let settings: AVCapturePhotoSettings
        var isRAW = false
        if raw, let rawType = photo.availableRawPhotoPixelFormatTypes.first {
            let processed = photo.availablePhotoCodecTypes.contains(.hevc) ? [AVVideoCodecKey: AVVideoCodecType.hevc] : [AVVideoCodecKey: AVVideoCodecType.jpeg]
            settings = AVCapturePhotoSettings(rawPixelFormatType: rawType, processedFormat: processed)
            isRAW = true
        } else if photo.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        // RAW capture only supports .speed; asking for more throws an NSInvalidArgumentException (crash).
        // Clamp to what the output supports so no combination can crash.
        let want: AVCapturePhotoOutput.QualityPrioritization = isRAW ? .speed : .quality
        settings.photoQualityPrioritization = want.rawValue <= photo.maxPhotoQualityPrioritization.rawValue ? want : photo.maxPhotoQualityPrioritization
        return await withCheckedContinuation { cont in
            continuation = cont
            photo.capturePhoto(with: settings, delegate: self)
            // Safety timeout: if the capture delegate never fires (hardware/driver error), resume with
            // nothing instead of leaving the shutter spinner stuck. Both this and the delegate clear
            // `continuation` on the main actor, so it resumes exactly once.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if let c = self.continuation { self.continuation = nil; c.resume(returning: (nil, nil)) }
            }
        }
    }

    nonisolated(unsafe) private var pendingProcessed: Data?
    nonisolated(unsafe) private var pendingRaw: Data?

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto p: AVCapturePhoto, error: Error?) {
        if p.isRawPhoto { pendingRaw = p.fileDataRepresentation() } else { pendingProcessed = p.fileDataRepresentation() }
    }
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor settings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let a = pendingProcessed, b = pendingRaw
        pendingProcessed = nil; pendingRaw = nil
        Task { @MainActor in self.continuation?.resume(returning: (a, b)); self.continuation = nil }
    }

    /// Save to the Photos library (processed + DNG as one asset pair when both exist).
    func save(processed: Data?, raw: Data?) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                if let processed { req.addResource(with: .photo, data: processed, options: nil) }
                if let raw { let o = PHAssetResourceCreationOptions(); o.uniformTypeIdentifier = UTType.dng.identifier; req.addResource(with: processed == nil ? .photo : .alternatePhoto, data: raw, options: o) }
            }
            return true
        } catch { return false }
    }

    // MARK: long exposure (frame averaging)

    func beginLongExposure(frames: Int) { accTarget = 0; accumulator = nil; accBuffers = []; accIndex = 0; accCount = 0; accumulated = 0; accumulating = true; accTarget = frames }

    /// Average of the accumulated frames, rendered to a UIImage.
    func finishLongExposure() -> UIImage? {
        accumulating = false
        guard let acc = accumulator, let cg = ctx.createCGImage(acc, from: acc.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { return nil }
        accumulator = nil; accBuffers = []
        return UIImage(cgImage: cg)
    }

    nonisolated private func flatten(_ img: CIImage, size: CGSize) -> CIImage? {
        let w = Int(size.width.rounded(.up)), h = Int(size.height.rounded(.up))
        guard w > 0, h > 0 else { return nil }
        if accBuffers.count < 2 || CVPixelBufferGetWidth(accBuffers[0]) != w || CVPixelBufferGetHeight(accBuffers[0]) != h {
            var made: [CVPixelBuffer] = []
            for _ in 0..<2 {
                var pb: CVPixelBuffer?
                CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_64RGBAHalf, [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary, &pb)
                if let pb { made.append(pb) }
            }
            guard made.count == 2 else { return nil }
            accBuffers = made; accIndex = 0
        }
        let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        accIndex = (accIndex + 1) % 2
        let buf = accBuffers[accIndex]
        accCtx.render(img, to: buf, bounds: CGRect(x: 0, y: 0, width: w, height: h), colorSpace: space)
        return CIImage(cvPixelBuffer: buf, options: [.colorSpace: space])
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pb)
        nonisolated(unsafe) let frame = ci
        if accTarget > 0, accCount < accTarget {
            // running mean: acc = acc·(n/(n+1)) + frame·(1/(n+1)); rendered small to keep it real-time
            let small = ci.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
            let n = Double(accCount)
            var next = small
            if let acc = accumulator {
                let a = ProImage.scale(acc, by: n / (n + 1)), b = ProImage.scale(small, by: 1 / (n + 1))
                let f = CIFilter.additionCompositing(); f.inputImage = a; f.backgroundImage = b
                next = f.outputImage?.cropped(to: small.extent) ?? small
            }
            // Flatten into our own buffer right now so the camera's frame buffer is released immediately.
            accumulator = flatten(next, size: small.extent.size)
            accCount += 1
            let c = accCount, done = accCount >= accTarget
            Task { @MainActor in
                self.accumulated = c
                if done { self.accTarget = 0; self.accumulating = false }   // ends the exposure → the view saves it
            }
        }
        Task { @MainActor in self.latest = frame }
    }
}

/// Pure image helpers for the pro camera overlays (testable).
enum ProImage {
    static func scale(_ img: CIImage, by k: Double) -> CIImage {
        let f = CIFilter.colorMatrix(); f.inputImage = img
        let v = CGFloat(k)
        f.rVector = CIVector(x: v, y: 0, z: 0, w: 0); f.gVector = CIVector(x: 0, y: v, z: 0, w: 0); f.bVector = CIVector(x: 0, y: 0, z: v, w: 0); f.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return f.outputImage ?? img
    }

    /// Focus peaking: strong edges painted red over the image.
    static func peaking(_ img: CIImage, threshold: Float = 0.25) -> CIImage {
        let e = CIFilter.edges(); e.inputImage = img; e.intensity = 4
        guard var edges = e.outputImage else { return img }
        let mono = CIFilter.maximumComponent(); mono.inputImage = edges; edges = mono.outputImage ?? edges
        // threshold → red where sharp, transparent elsewhere
        let th = CIFilter.colorThreshold(); th.inputImage = edges; th.threshold = threshold
        guard let mask = th.outputImage else { return img }
        let red = CIImage(color: CIColor(red: 1, green: 0.1, blue: 0.1)).cropped(to: img.extent)
        let blend = CIFilter.blendWithMask(); blend.inputImage = red; blend.backgroundImage = img; blend.maskImage = mask
        return blend.outputImage?.cropped(to: img.extent) ?? img
    }

    /// Zebras: pixels brighter than `level` get a magenta tint so blown highlights are obvious.
    static func zebras(_ img: CIImage, level: Float = 0.96) -> CIImage {
        let mono = CIFilter.maximumComponent(); mono.inputImage = img
        let th = CIFilter.colorThreshold(); th.inputImage = mono.outputImage; th.threshold = level
        guard let mask = th.outputImage else { return img }
        let magenta = CIImage(color: CIColor(red: 1, green: 0.2, blue: 0.9)).cropped(to: img.extent)
        let blend = CIFilter.blendWithMask(); blend.inputImage = magenta; blend.backgroundImage = img; blend.maskImage = mask
        return blend.outputImage?.cropped(to: img.extent) ?? img
    }

    /// 32-bin luminance histogram, normalized 0…1.
    static func histogram(_ img: CIImage, context: CIContext, bins: Int = 32) -> [Float] {
        let small = img.transformed(by: CGAffineTransform(scaleX: 0.1, y: 0.1))
        let f = CIFilter.areaHistogram(); f.inputImage = small; f.extent = small.extent; f.count = bins; f.scale = 1
        guard let out = f.outputImage else { return [] }
        var px = [Float](repeating: 0, count: bins * 4)
        context.render(out, toBitmap: &px, rowBytes: bins * 16, bounds: CGRect(x: 0, y: 0, width: bins, height: 1), format: .RGBAf, colorSpace: nil)
        var lum = [Float](repeating: 0, count: bins)
        for i in 0..<bins {
            let r: Float = px[i * 4], g: Float = px[i * 4 + 1], b: Float = px[i * 4 + 2]
            lum[i] = r * 0.2126 + g * 0.7152 + b * 0.0722
        }
        let mx = lum.max() ?? 1
        if mx > 0 { lum = lum.map { $0 / mx } }
        return lum
    }

    static func shutterLabel(_ s: Double) -> String {
        // A camera reports an invalid/zero exposureDuration for the first instant after the session
        // is built (before streaming), which made 1/s infinite and Int(infinity) trap. Guard it.
        guard s.isFinite, s > 0 else { return "—" }
        if s >= 1 { return String(format: "%.0f s", s) }
        if s >= 0.1 { return String(format: "%.1f s", s) }
        return "1/\(Int((1 / s).rounded()))"
    }
}

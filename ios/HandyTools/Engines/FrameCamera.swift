import UIKit
import AVFoundation
import CoreImage
import MetalKit
import SwiftUI

/// A camera that hands you every frame as a CIImage (upright), for tools that transform the picture
/// live — Color Vision, Magnifier+, Scene Describer. Start/stop are safe to call repeatedly.
@MainActor
final class FrameCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var latest: CIImage?
    @Published var torchOn = false
    @Published var authorized = true
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private(set) var device: AVCaptureDevice?
    private let queue = DispatchQueue(label: "tenzy.frames", qos: .userInteractive)
    nonisolated(unsafe) private var paused = false
    nonisolated(unsafe) private var rotation: CGFloat = 90

    var isAvailable: Bool { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }

    func start(preset: AVCaptureSession.Preset = .hd1280x720) {
        nonisolated(unsafe) let s = session
        if !session.inputs.isEmpty { if !session.isRunning { DispatchQueue.global().async { s.startRunning() } }; return }
        AVCaptureDevice.requestAccess(for: .video) { ok in Task { @MainActor in self.authorized = ok } }
        session.beginConfiguration()
        session.sessionPreset = preset
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else { session.commitConfiguration(); return }
        device = dev
        session.addInput(input)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        if let c = output.connection(with: .video), c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90; rotation = 0 }
        session.commitConfiguration()
        DispatchQueue.global().async { s.startRunning() }
    }

    func stop() {
        if torchOn { setTorch(false) }
        nonisolated(unsafe) let s = session
        if session.isRunning { DispatchQueue.global().async { s.stopRunning() } }
    }

    func setPaused(_ p: Bool) { paused = p }

    func setZoom(_ z: CGFloat) {
        guard let d = device else { return }
        try? d.lockForConfiguration()
        d.videoZoomFactor = max(1, min(z, d.activeFormat.videoMaxZoomFactor))
        d.unlockForConfiguration()
    }

    func setTorch(_ on: Bool) {
        guard let d = device, d.hasTorch else { return }
        try? d.lockForConfiguration()
        if on { try? d.setTorchModeOn(level: 1.0) } else { d.torchMode = .off }
        d.unlockForConfiguration()
        torchOn = on
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !paused, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ci = CIImage(cvPixelBuffer: pb)
        if rotation != 0 { ci = ci.oriented(.right) }
        nonisolated(unsafe) let frame = ci
        Task { @MainActor in self.latest = frame }
    }
}

/// Draws a CIImage with Metal, aspect-filled. Set `image` from the main thread; it redraws once per set.
final class MetalImageView: MTKView, MTKViewDelegate {
    private var ciContext: CIContext?
    private var queue: MTLCommandQueue?
    var image: CIImage? { didSet { setNeedsDisplay() } }

    init() {
        let dev = MTLCreateSystemDefaultDevice()
        super.init(frame: .zero, device: dev)
        if let dev { ciContext = CIContext(mtlDevice: dev, options: [.cacheIntermediates: false]); queue = dev.makeCommandQueue() }
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = true
        backgroundColor = .black
        colorPixelFormat = .bgra8Unorm
        delegate = self
    }
    required init(coder: NSCoder) { fatalError() }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let img = image, let ctx = ciContext, let q = queue, let drawable = currentDrawable, let cb = q.makeCommandBuffer() else { return }
        let bounds = CGRect(origin: .zero, size: drawableSize)
        guard img.extent.width > 0, img.extent.height > 0, bounds.width > 0 else { return }
        let scale = max(bounds.width / img.extent.width, bounds.height / img.extent.height)
        var out = img.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        out = out.transformed(by: CGAffineTransform(translationX: (bounds.width - out.extent.width) / 2 - out.extent.minX, y: (bounds.height - out.extent.height) / 2 - out.extent.minY))
        ctx.render(out, to: drawable.texture, commandBuffer: cb, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
        cb.present(drawable)
        cb.commit()
    }

    /// Snapshot of what's on screen (the processed frame), for saving/sharing.
    func snapshot() -> UIImage? {
        guard let img = image, let ctx = ciContext, let cg = ctx.createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// SwiftUI wrapper: give it the frame to show.
struct ProcessedFrameView: UIViewRepresentable {
    let image: CIImage?
    let holder: MetalViewHolder
    func makeUIView(context: Context) -> MetalImageView { let v = MetalImageView(); holder.view = v; return v }
    func updateUIView(_ v: MetalImageView, context: Context) { v.image = image }
}

/// Lets SwiftUI code reach the Metal view (for snapshots) without owning it.
@MainActor final class MetalViewHolder { weak var view: MetalImageView? }

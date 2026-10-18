import SwiftUI
import AVFoundation
import UIKit

/// Turns the camera into a magnifying glass: pinch or slide to zoom way past what the Camera app
/// allows, flip the light on, and freeze a frame to read tiny print without a steady hand.
struct MagnifierView: View {
    @StateObject private var cam = MagnifierCamera()
    @State private var zoom: CGFloat = 1.5

    var body: some View {
        ToolPage(title: "Magnifier", subtitle: "Read the fine print. Zoom, light it up, freeze the frame.") {
            ZStack {
                MagnifierPreview(camera: cam)
                    .aspectRatio(3.0/4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                if cam.frozen != nil {
                    Text("Frozen").font(HandyFont.caption).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule()).padding(HandySpacing.s12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            HStack(spacing: HandySpacing.s12) {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $zoom, in: 1...8) { _ in cam.setZoom(zoom) }
                    .tint(HandyColor.accent)
                    .onChange(of: zoom) { _, z in cam.setZoom(z) }
                Image(systemName: "plus.magnifyingglass")
            }.foregroundStyle(HandyColor.textSecondary)

            HStack(spacing: HandySpacing.s16) {
                Button { cam.toggleTorch() } label: {
                    Label(cam.torchOn ? "Light off" : "Light on", systemImage: cam.torchOn ? "flashlight.off.fill" : "flashlight.on.fill").frame(maxWidth: .infinity)
                }.compactButton()
                Button { cam.toggleFreeze() } label: {
                    Label(cam.frozen == nil ? "Freeze" : "Live", systemImage: cam.frozen == nil ? "pause.fill" : "play.fill").frame(maxWidth: .infinity)
                }.primaryButton()
            }
        }
        .onAppear { cam.start(); cam.setZoom(zoom) }
        .onDisappear { cam.stop() }
    }
}

@MainActor
final class MagnifierCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var frozen: UIImage?
    @Published var torchOn = false
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?
    private let ctx = CIContext()
    private var latest: CGImage?

    func start() {
        guard session.inputs.isEmpty else { if !session.isRunning { DispatchQueue.global().async { [session] in session.startRunning() } }; return }
        session.sessionPreset = .high
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else { return }
        device = dev
        session.addInput(input)
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "mag.frames"))
        if session.canAddOutput(output) { session.addOutput(output) }
        DispatchQueue.global().async { [session] in session.startRunning() }
    }

    func stop() { if torchOn { toggleTorch() }; if session.isRunning { DispatchQueue.global().async { [session] in session.stopRunning() } } }

    func setZoom(_ z: CGFloat) {
        guard let d = device else { return }
        try? d.lockForConfiguration()
        d.videoZoomFactor = max(1, min(z, d.activeFormat.videoMaxZoomFactor))
        d.unlockForConfiguration()
    }

    func toggleTorch() {
        guard let d = device, d.hasTorch else { return }
        try? d.lockForConfiguration()
        torchOn.toggle()
        try? d.setTorchModeOn(level: torchOn ? 1.0 : 0.01)
        if !torchOn { d.torchMode = .off }
        d.unlockForConfiguration()
    }

    func toggleFreeze() {
        if frozen == nil, let cg = latest { frozen = UIImage(cgImage: cg); HandyHaptics.tap() }
        else { frozen = nil }
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pb)
        let context = CIContext()
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return }
        Task { @MainActor in self.latest = cg }
    }
}

struct MagnifierPreview: UIViewRepresentable {
    let camera: MagnifierCamera
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView(); v.videoLayer.session = camera.session; v.videoLayer.videoGravity = .resizeAspectFill; return v
    }
    func updateUIView(_ v: PreviewView, context: Context) {
        v.frozenView.image = camera.frozen
        v.frozenView.isHidden = camera.frozen == nil
    }
    final class PreviewView: UIView {
        let frozenView = UIImageView()
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            frozenView.contentMode = .scaleAspectFill; frozenView.clipsToBounds = true
            frozenView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(frozenView)
            NSLayoutConstraint.activate([
                frozenView.topAnchor.constraint(equalTo: topAnchor), frozenView.bottomAnchor.constraint(equalTo: bottomAnchor),
                frozenView.leadingAnchor.constraint(equalTo: leadingAnchor), frozenView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
        required init?(coder: NSCoder) { fatalError() }
    }
}

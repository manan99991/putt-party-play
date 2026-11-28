import SwiftUI
import AVFoundation

/// Home's camera (Manan, 28 Nov): one button for a picture OR a video, opening straight into the Pro camera — it sets
/// itself up for the scene, photos at full quality, video in HD with sound. Whatever was taken is handed back, and Home
/// shows what Tenzy can do with a photo, or with a video.
struct HomeCameraView: View {
    let done: (CameraTake?) -> Void
    @StateObject private var cam = ProCameraController()
    @State private var holder = MetalViewHolder()
    @State private var busy = false
    @State private var zoom: CGFloat = 1
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ZStack {
                    ProcessedFrameView(image: cam.latest, holder: holder, fit: false)
                        .clipped()
                    thirds
                    if !cam.authorized && !Self.fake {
                        PermissionOffCard(icon: "camera.fill", line: L("Camera access is off"),
                                          sub: L("Tenzy needs the camera for this. Turn it on in Settings, then come back."))
                            .padding(HandySpacing.s16)
                    }
                    if flash { Color.white.opacity(0.7).allowsHitTesting(false) }
                    VStack {
                        Spacer()
                        if cam.recording {
                            Label(VideoFacts.clock(cam.recordSeconds), systemImage: "record.circle")
                                .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.red.opacity(0.85), in: Capsule())
                                .accessibilityIdentifier("homecam-recording")
                        }
                        zoomRow.padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                modeRow.padding(.vertical, 10)
                shutterRow.padding(.bottom, 14)
                Text(L(cam.videoMode ? "Tap to start, tap again to stop" : "Tap for a photo · swipe to Video to film"))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75)).padding(.bottom, 8)
            }
        }
        .statusBarHidden()
        .onAppear { if Launch.startHardware { cam.start() } }
        .onDisappear {
            if cam.recording { Task { _ = await cam.stopRecording() } }
            cam.stop()
        }
        .accessibilityIdentifier("homecam")
    }

    private var topBar: some View {
        HStack {
            Button { close() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel(L("Close")).accessibilityIdentifier("homecam-close")
            Spacer()
            Text("PRO").font(.system(size: 12, weight: .heavy)).foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 5).background(Color.yellow, in: Capsule())
                .accessibilityLabel(L("Pro camera"))
            Spacer()
            Text(cam.videoMode ? "HD · \(cam.videoScene.fps)" : "HEIF").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 64, height: 30).background(.white.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, HandySpacing.s16).padding(.vertical, 6)
    }

    private var thirds: some View {
        GeometryReader { g in
            Path { p in
                for i in 1...2 {
                    p.move(to: CGPoint(x: g.size.width * CGFloat(i) / 3, y: 0)); p.addLine(to: CGPoint(x: g.size.width * CGFloat(i) / 3, y: g.size.height))
                    p.move(to: CGPoint(x: 0, y: g.size.height * CGFloat(i) / 3)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height * CGFloat(i) / 3))
                }
            }.stroke(.white.opacity(0.25), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private var zoomRow: some View {
        HStack(spacing: 10) {
            ForEach([1.0, 2.0], id: \.self) { (z: CGFloat) in
                Button { zoom = z; cam.zoom(z) } label: {
                    Text(z == 1 ? "1×" : "2×").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(zoom == z ? Color.yellow : .white)
                        .frame(width: 40, height: 40).background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel(z == 1 ? L("Normal zoom") : L("Zoom in two times"))
            }
        }
    }

    private var modeRow: some View {
        HStack(spacing: 28) {
            ForEach([false, true], id: \.self) { video in
                Button { if !cam.recording { cam.setVideoMode(video) } } label: {
                    Text(L(video ? "VIDEO" : "PHOTO")).font(.system(size: 14, weight: .bold)).tracking(1)
                        .foregroundStyle(cam.videoMode == video ? Color.yellow : .white.opacity(0.75))
                        .frame(minWidth: 70, minHeight: 36)
                }
                .disabled(cam.recording || busy)
                .accessibilityIdentifier(video ? "homecam-video" : "homecam-photo")
                .accessibilityAddTraits(cam.videoMode == video ? .isSelected : [])
            }
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard !cam.recording, !busy else { return }
            if v.translation.width < -30 { cam.setVideoMode(true) } else if v.translation.width > 30 { cam.setVideoMode(false) }
        })
    }

    private var shutterRow: some View {
        Button { shutter() } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                if cam.videoMode {
                    RoundedRectangle(cornerRadius: cam.recording ? 6 : 31, style: .continuous).fill(Color.red)
                        .frame(width: cam.recording ? 30 : 62, height: cam.recording ? 30 : 62)
                } else {
                    Circle().fill(.white).frame(width: 64, height: 64)
                }
                if busy { ProgressView().tint(.black) }
            }
            .animation(.easeOut(duration: HandyMotion.fast), value: cam.recording)
        }
        .disabled(busy || (!cam.authorized && !Self.fake))
        .accessibilityLabel(L(cam.videoMode ? (cam.recording ? "Stop recording" : "Start recording") : "Take a photo"))
        .accessibilityIdentifier("homecam-shutter")
    }

    /// UI tests (-homecam): the simulator has no camera, so the shutter hands back a sample photo or a sample clip —
    /// the screen, the photo/video switch and what Home does next are what's checked.
    private static var fake: Bool { Launch.uitest && Launch.args.contains("-homecam") }
    @State private var fakeRecording = false

    private func shutter() {
        if Self.fake {
            if cam.videoMode {
                if fakeRecording { Task { if let u = await SampleAssets.movie(withSound: true) { finish(.video(u)) } } }
                fakeRecording.toggle()
            } else { finish(.photo(SampleAssets.receipt())) }
            return
        }
        if cam.videoMode {
            if cam.recording {
                busy = true
                Task {
                    let u = await cam.stopRecording()
                    busy = false
                    if let u { finish(.video(u)) }
                }
            } else {
                cam.startRecording()
            }
            return
        }
        busy = true
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation { flash = false } }
        Task {
            let (data, _) = await cam.capture(raw: false)
            busy = false
            if let d = data, let img = UIImage(data: d) { finish(.photo(img.normalizedUp())) }
        }
    }

    private func finish(_ t: CameraTake) { cam.stop(); done(t) }

    private func close() {
        if cam.recording {
            Task { if let u = await cam.stopRecording() { finish(.video(u)) } else { cam.stop(); done(nil) } }
        } else { cam.stop(); done(nil) }
    }

    /// No camera here (the simulator): the old picker, which opens the photo library instead.
    static var available: Bool { fake || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }
}

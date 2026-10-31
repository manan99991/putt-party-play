import SwiftUI
import CoreImage
import PhotosUI
import AVFoundation

/// Scene Describer — hear what the camera sees. Tap once for a description, or let it narrate
/// continuously and speak only when the scene changes. Reads text aloud too. Built for low vision,
/// also handy with your eyes busy. Not a mobility or safety aid.
struct SceneDescriberView: View {
    @StateObject private var cam = FrameCamera()
    @StateObject private var speaker = Speaker()
    @State private var holder = MetalViewHolder()
    @State private var description = ""
    @State private var busy = false
    @State private var continuous = false
    @State private var last: SceneDescriber.Perception?
    @State private var photoItem: PhotosPickerItem?
    @State private var tickTask: Task<Void, Never>?
    @AppStorage("describe.rate") private var rate = Double(AVSpeechUtteranceDefaultSpeechRate)
    private let ctx = CIContext()

    var embedded = false
    var body: some View {
        content
        .onAppear { if Launch.startHardware { cam.start(preset: .hd1280x720) }; speaker.rate = Float(rate); if Launch.sample { Task { await describe(SampleAssets.photo(), speak: false) } } }
        .onDisappear { stopContinuous(); cam.stop(); speaker.stop() }
        .onChange(of: photoItem) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self), let ui = UIImage(data: d) { await describe(ui, speak: true) }
            }
        }
    }
    @ViewBuilder private var content: some View {
        if embedded { VStack(alignment: .leading, spacing: HandySpacing.s12) { panel } }
        else { ToolPage(title: "Scene Describer", subtitle: "Tap to hear what's in front of the camera, or let it narrate as the scene changes.") { panel } }
    }
    @ViewBuilder private var panel: some View {
            HowTo("describe", [
                "Point the camera at what is in front of you and tap to describe it.",
                "It speaks what it sees; tap Repeat to hear it again.",
                "Set the speaking speed to taste.",
            ])
            ZStack(alignment: .bottom) {
                ProcessedFrameView(image: cam.latest, holder: holder)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay {
                        if !cam.authorized {
                            PermissionOffCard(line: "Camera access is off", sub: "Turn it on in Settings, or pick a photo with the photo button below.")
                                .background(HandyColor.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        }
                    }
                    .onTapGesture { describeNow() }
                    .accessibilityLabel("Camera view. Double tap to describe.")
                HStack(spacing: HandySpacing.s8) {
                    Button { continuous.toggle(); if continuous { startContinuous() } else { stopContinuous() } } label: {
                        Label(continuous ? "Stop narrating" : "Narrate continuously", systemImage: continuous ? "stop.fill" : "waveform.and.mic")
                    }.compactButton()
                    Spacer()
                    PhotosPicker(selection: $photoItem, matching: .images) { Image(systemName: "photo").frame(width: 36, height: 36) }.compactButton()
                }.padding(HandySpacing.s12)
            }

            Button { describeNow() } label: {
                HStack { if busy { ProgressView().tint(.white) }; Label(busy ? "Looking…" : "Describe what's in front of me", systemImage: "eye.fill") }.frame(maxWidth: .infinity)
            }.primaryButton().disabled(busy || cam.latest == nil)
            .accessibilityHint("Speaks a description of the camera view")

            if !description.isEmpty {
                VStack(alignment: .leading, spacing: HandySpacing.s8) {
                    Text(description).font(.system(size: 20, weight: .medium)).textSelection(.enabled)
                    HStack(spacing: HandySpacing.s8) {
                        Button { speaker.say(description) } label: { Label("Repeat", systemImage: "speaker.wave.2") }.compactButton()
                        Button { readText() } label: { Label("Read the text", systemImage: "text.viewfinder") }.compactButton()
                        if speaker.speaking { Button { speaker.stop() } label: { Label("Stop", systemImage: "stop.fill") }.compactButton() }
                        Spacer()
                    }
                }.cardStyle()
            }

            HStack { Image(systemName: "tortoise"); Slider(value: $rate, in: 0.3...0.7).tint(HandyColor.accent).onChange(of: rate) { _, r in speaker.rate = Float(r) }; Image(systemName: "hare") }.foregroundStyle(HandyColor.textSecondary)

            Text(AIEngine.isAvailable ? "Uses the camera and on-device Apple Intelligence; nothing leaves the phone. Descriptions are best-effort — not a mobility or safety aid."
                                      : "Runs on the phone's vision engine; with Apple Intelligence the sentences get more natural. Best-effort — not a mobility or safety aid.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
    }

    private func currentImage() -> UIImage? {
        guard let ci = cam.latest, let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func describeNow() {
        guard let img = currentImage() else { return }
        Task { await describe(img, speak: true) }
    }

    @MainActor private func describe(_ img: UIImage, speak: Bool, onlyIfChanged: Bool = false) async {
        busy = true; defer { busy = false }
        let small = img.resized(maxDimension: 1024)
        let p = await Task.detached(priority: .userInitiated) { SceneDescriber.perceive(small) }.value
        if onlyIfChanged, let last, last == p { return }
        last = p
        let base = SceneDescriber.compose(p)
        let text = await SceneDescriber.polish(p, fallback: base)
        description = text
        if speak { speaker.say(text) }
    }

    private func readText() {
        guard let img = currentImage() else { return }
        Task {
            let s = await AIEngine.recognizeText(img)
            if s.isEmpty { speaker.say("I don't see any text.") } else { description = s; speaker.say(s) }
        }
    }

    private func startContinuous() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                if let img = currentImage(), !speaker.speaking { await describe(img, speak: true, onlyIfChanged: true) }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
    private func stopContinuous() { tickTask?.cancel(); tickTask = nil; continuous = false }
}

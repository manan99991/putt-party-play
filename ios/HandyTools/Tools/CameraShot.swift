import SwiftUI
import UIKit
import AVFoundation

/// The phone's camera, for any tool: take one picture and hand it back (nil when cancelled). Where there's no camera
/// (the simulator), the photo library opens instead so the flow still works.
struct CameraShot: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done((info[.originalImage] as? UIImage)?.normalizedUp())
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

/// What a tool's camera button brings back: a picture, or a clip it recorded (a file in Tenzy's own temporary folder).
enum CameraTake {
    case photo(UIImage)
    case video(URL)
}

/// The phone's camera recording one clip (sound included), handed back as a file Tenzy owns. nil when cancelled.
struct CameraClip: UIViewControllerRepresentable {
    let done: (URL?) -> Void
    func makeCoordinator() -> Coord { Coord(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { p.sourceType = .camera }
        p.mediaTypes = ["public.movie"]
        p.videoQuality = .typeHigh
        p.videoMaximumDuration = 600
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (URL?) -> Void
        init(done: @escaping (URL?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let src = info[.mediaURL] as? URL else { done(nil); return }
            // The camera's own file can be removed once this screen closes: keep a copy.
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent("camera-\(UUID().uuidString).\(src.pathExtension.isEmpty ? "mov" : src.pathExtension)")
            done((try? FileManager.default.copyItem(at: src, to: dst)) != nil ? dst : src)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

/// A tool's camera button (26 Nov, Manan: "camera button for tools that might need a camera directly in the app"):
/// take a photo — or record a clip, for video tools — right inside the tool, instead of only picking from Photos.
/// If the camera is switched off for Tenzy it says so and offers Settings, never a dead button. Under UI tests with
/// `-fakecamera` it hands over a generated picture or clip at once, so every tool's camera path is tested.
struct CameraButton<Label: View>: View {
    var video = false
    let took: (CameraTake) -> Void
    @ViewBuilder let label: () -> Label
    @State private var open = false
    @State private var denied = false

    var body: some View {
        Button {
            if Launch.uitest, Launch.args.contains("-fakecamera") {
                if video { Task { if let u = await SampleAssets.movie(seconds: 3, withSound: true) { took(.video(u)) } } }
                else { took(.photo(SampleAssets.photo())) }
                return
            }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .denied, .restricted: denied = true
            default: open = true
            }
        } label: { label() }
        .fullScreenCover(isPresented: $open) {
            Group {
                if video {
                    CameraClip { url in open = false; if let url { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { took(.video(url)) } } }
                } else {
                    CameraShot { img in open = false; if let img { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { took(.photo(img)) } } }
                }
            }
            .ignoresSafeArea()
        }
        .alert(L("The camera is off for Tenzy"), isPresented: $denied) {
            Button(L("Open Settings")) { Permission.openSettings() }
            Button(L("Not now"), role: .cancel) {}
        } message: {
            Text(L("Turn on Camera for Tenzy in Settings to take a photo here. Photos stay on your phone."))
        }
    }
}

import SwiftUI
import UIKit

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

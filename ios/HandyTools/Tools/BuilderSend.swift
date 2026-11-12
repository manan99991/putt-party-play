import SwiftUI
import MessageUI
import UniformTypeIdentifiers

/// A finished result, ready to hand to Mail or Messages: some text, some files, or both.
struct Outbox: Equatable {
    var text: String?
    var files: [URL] = []

    /// - Parameters named/tool: the tool's file-name pattern and its name, so the file leaves with a clear name.
    static func make(_ p: ChainPayload, named: String? = nil, tool: String = "", dir: URL = FileManager.default.temporaryDirectory) -> Outbox? {
        func file(_ d: Data, _ ext: String) -> Outbox? {
            let u = dir.appendingPathComponent(ChainName.file(pattern: named, tool: tool, ext: ext))
            return (try? d.write(to: u)) != nil ? Outbox(files: [u]) : nil
        }
        switch p {
        case .text(let t): return Outbox(text: t)
        case .image(let i): return i.jpegData(compressionQuality: 0.92).flatMap { file($0, "jpg") }
        case .file(let d, let ext): return file(d, ext)
        }
    }

    static func mime(_ url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}

/// The system email or message composer, already filled in from a tool's "Then" step. iOS never lets an app send
/// on its own, so this is the shortest honest path: the composer opens complete and the person taps Send.
struct SendSheet: UIViewControllerRepresentable {
    let finish: ChainFinish
    let subject: String
    let box: Outbox
    @Environment(\.dismiss) private var dismiss

    static func canSend(_ kind: ChainFinish.Kind) -> Bool {
        switch kind {
        case .share, .open: return true
        case .mail: return MFMailComposeViewController.canSendMail()
        case .message: return MFMessageComposeViewController.canSendText()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    func makeUIViewController(context: Context) -> UIViewController {
        if finish.kind == .mail {
            let vc = MFMailComposeViewController()
            vc.mailComposeDelegate = context.coordinator
            vc.setToRecipients(finish.recipients)
            vc.setSubject(subject)
            vc.setMessageBody(box.text ?? "", isHTML: false)
            for u in box.files {
                if let d = try? Data(contentsOf: u) { vc.addAttachmentData(d, mimeType: Outbox.mime(u), fileName: u.lastPathComponent) }
            }
            return vc
        }
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = finish.recipients
        if let t = box.text { vc.body = t }
        if MFMessageComposeViewController.canSendAttachments() {
            for u in box.files { vc.addAttachmentURL(u, withAlternateFilename: nil) }
        }
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { dismiss() }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { dismiss() }
    }
}

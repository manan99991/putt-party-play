import SwiftUI
import ContactsUI
import PDFKit

/// More ways to hand something to a tool besides typing or picking a photo: what you say, a contact, a PDF.

enum InputText {
    /// Adds new words under what is already in the box, without piling up blank lines.
    static func joined(_ existing: String, _ adding: String) -> String {
        let a = existing.trimmingCharacters(in: .whitespacesAndNewlines), b = adding.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + "\n" + b
    }

    /// A contact as plain lines (name, company, each phone, each email), which is what the text steps read.
    static func contact(name: String, company: String, phones: [String], emails: [String]) -> String {
        ([name, company] + phones + emails).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum PDFInput {
    private static func open(_ url: URL) -> PDFDocument? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return PDFDocument(data: data)
    }

    /// The words in a PDF. nil if it can't be opened; empty if it has no text (a scan).
    static func text(from url: URL) -> String? {
        guard let doc = open(url) else { return nil }
        return (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Each page as a picture sharp enough to read (long side about 2000 px), up to `limit` pages.
    static func pages(from url: URL, limit: Int = 20) -> [UIImage] {
        guard let doc = open(url) else { return [] }
        return (0..<min(doc.pageCount, limit)).compactMap { i in
            guard let page = doc.page(at: i) else { return nil }
            let b = page.bounds(for: .mediaBox)
            let longSide = max(b.width, b.height, 1)
            let scale = min(3, 2000 / longSide)
            let size = CGSize(width: b.width * scale, height: b.height * scale)
            let f = UIGraphicsImageRendererFormat.default(); f.scale = 1; f.opaque = true
            return UIGraphicsImageRenderer(size: size, format: f).image { c in
                UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
                c.cgContext.translateBy(x: 0, y: size.height)
                c.cgContext.scaleBy(x: scale, y: -scale)
                c.cgContext.translateBy(x: -b.minX, y: -b.minY)
                page.draw(with: .mediaBox, to: c.cgContext)
            }
        }
    }
}

/// Apple's contact picker. It needs no permission: Tenzy only receives the one contact the person taps.
struct ContactPickerSheet: UIViewControllerRepresentable {
    /// The picked contact as plain lines, or nil if the picker was closed.
    var onDone: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }
    // The picker is shown from a small host screen: placed directly inside a SwiftUI sheet it can come up blank.
    func makeUIViewController(context: Context) -> Host {
        let host = Host()
        host.picker.delegate = context.coordinator
        return host
    }
    func updateUIViewController(_ vc: Host, context: Context) {}

    final class Host: UIViewController {
        let picker = CNContactPickerViewController()
        private var shown = false
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            if !shown { shown = true; present(picker, animated: false) }
        }
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onDone: (String?) -> Void
        init(onDone: @escaping (String?) -> Void) { self.onDone = onDone }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            onDone(InputText.contact(name: name, company: contact.organizationName,
                                     phones: contact.phoneNumbers.map { $0.value.stringValue },
                                     emails: contact.emailAddresses.map { $0.value as String }))
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { onDone(nil) }
    }
}

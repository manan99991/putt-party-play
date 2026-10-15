import UIKit
import UniformTypeIdentifiers

/// "Save to Clips" in the Share Sheet. Grabs shared text or a URL, saves it, shows a checkmark, closes.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let label = UILabel()
        label.text = "✓ Saved to Clips"; label.font = .boldSystemFont(ofSize: 20); label.textAlignment = .center
        label.backgroundColor = .systemBackground; label.layer.cornerRadius = 16; label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 220), label.heightAnchor.constraint(equalToConstant: 64),
        ])
        Task { await save(); try? await Task.sleep(for: .milliseconds(700)); extensionContext?.completeRequest(returningItems: nil) }
    }

    private func save() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        for item in items {
            for p in item.attachments ?? [] {
                if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let s = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { ClipStore.add(s); return }
                if p.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL { ClipStore.add(u.absoluteString); return }
            }
            if let s = item.attributedContentText?.string { ClipStore.add(s); return }
        }
    }
}

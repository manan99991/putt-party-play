import UIKit
import SwiftUI

/// "Tenzy" in the Share Sheet. Share photos or text from any app, pick one of your tools, and it runs right here;
/// the result can go straight on to Messages, WhatsApp, Mail or anywhere else.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel()
        model.finish = { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
        model.shareOn = { [weak self] items in
            guard let self else { return }
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self.view
            vc.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY - 80, width: 1, height: 1)
            // Once it has been sent on, there is nothing left to do here.
            vc.completionWithItemsHandler = { _, completed, _, _ in if completed { model.finish() } }
            self.present(vc, animated: true)
        }
        let host = UIHostingController(rootView: ShareRunView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let typed = items.compactMap { $0.attributedContentText?.string }.first
        Task { await model.load(providers, typedText: typed) }
    }
}

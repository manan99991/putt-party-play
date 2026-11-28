import SwiftUI
import UIKit

/// Opens the phone's Share sheet over whatever is on screen, straight from UIKit.
///
/// 27 Nov: a SwiftUI ShareLink inside a tool's sheet took the sheet's Done button with it when the Share sheet closed
/// (and on Manan's phone blanked the whole page). Presenting the Share sheet ourselves from the top-most screen leaves
/// the tool's page, its toolbar and its Done button exactly as they were.
@MainActor enum SharePresenter {
    static func present(_ items: [Any], from anchor: CGRect? = nil) {
        guard !items.isEmpty,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.keyWindow ?? scene.windows.first,
              var top = window.rootViewController else { return }
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {   // iPad: point at the button that was tapped
            pop.sourceView = window
            pop.sourceRect = anchor ?? CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = anchor == nil ? [] : .any
        }
        top.present(vc, animated: true)
    }
}

/// A Share button for files that already exist — drop-in for `ShareLink(item: url) { label }`.
struct ShareFilesButton<Label: View>: View {
    let urls: [URL]
    @ViewBuilder var label: () -> Label
    @State private var frame: CGRect = .zero

    init(_ urls: [URL], @ViewBuilder label: @escaping () -> Label) { self.urls = urls; self.label = label }
    init(_ url: URL, @ViewBuilder label: @escaping () -> Label) { self.init([url], label: label) }

    var body: some View {
        Button { SharePresenter.present(urls, from: frame == .zero ? nil : frame) } label: { label() }
            .disabled(urls.isEmpty)
            .background(GeometryReader { g in Color.clear.onAppear { frame = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, f in frame = f } })
    }
}

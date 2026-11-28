import SwiftUI
import UIKit

/// UI tests only: what UIKit's navigation bar really holds, read off the hosting controller, shown as an invisible
/// label the test prints (28 Nov: Done vanished after every Share sheet three times over; the fixes were guesses).
/// Reports how often the screen appeared, whether the bar is hidden, and the bar's left and right items.
struct NavProbe: UIViewControllerRepresentable {
    @Binding var report: String
    func makeUIViewController(context: Context) -> ProbeVC { ProbeVC(report: $report) }
    func updateUIViewController(_ vc: ProbeVC, context: Context) {}

    final class ProbeVC: UIViewController {
        var report: Binding<String>
        private var appears = 0
        init(report: Binding<String>) { self.report = report; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            appears += 1
            refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() }
        }
        func refresh() {
            var host: UIViewController? = parent
            while let h = host, h.navigationController == nil { host = h.parent }
            guard let nav = (host ?? self).navigationController else { report.wrappedValue = "appears=\(appears) nav=none"; return }
            let top = nav.topViewController
            let item = top?.navigationItem
            let left = (item?.leftBarButtonItems ?? []).count, right = (item?.rightBarButtonItems ?? []).count
            let presented = nav.presentedViewController.map { String(describing: type(of: $0)) } ?? "-"
            report.wrappedValue = "appears=\(appears) hidden=\(nav.isNavigationBarHidden) barAlpha=\(nav.navigationBar.alpha) left=\(left) right=\(right) back=\(item?.hidesBackButton == true ? "hidden" : "shown") stack=\(nav.viewControllers.count) presented=\(presented)"
        }
    }
}

extension View {
    /// Adds the probe (UI tests only), as an invisible element the test can read by id "nav-probe".
    @ViewBuilder func navProbe() -> some View {
        if Launch.uitest { modifier(NavProbeModifier()) } else { self }
    }
}

private struct NavProbeModifier: ViewModifier {
    @State private var report = "unset"
    func body(content: Content) -> some View {
        content
            .background(NavProbe(report: $report).frame(width: 1, height: 1).allowsHitTesting(false))
            .overlay(alignment: .bottomLeading) {
                Text(report).font(.system(size: 1)).opacity(0.01).accessibilityIdentifier("nav-probe").allowsHitTesting(false)
            }
    }
}

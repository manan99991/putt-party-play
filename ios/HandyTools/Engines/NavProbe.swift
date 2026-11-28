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
            // Read again every second, so the report is what the bar holds now, not when the page first showed.
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        }
        private var timer: Timer?
        override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); timer?.invalidate() }
        /// What really draws in the bar: every visible control or label, with its accessibility state.
        private func barViews(_ bar: UINavigationBar) -> String {
            var out: [String] = []
            func walk(_ v: UIView, _ depth: Int) {
                guard depth < 14, out.count < 12 else { return }
                let shown = !v.isHidden && v.alpha > 0.01 && v.window != nil
                if (v is UIControl || v is UILabel || v is UIImageView), v.bounds.width > 4 {
                    let name = String(describing: type(of: v)).replacingOccurrences(of: "_", with: "")
                    let text = (v as? UILabel)?.text ?? v.accessibilityLabel ?? ""
                    out.append("\(name.prefix(22))[\(text.prefix(12))]\(shown ? "" : "·HIDDEN")\(v.accessibilityElementsHidden ? "·AXHIDDEN" : "")@\(Int(v.convert(v.bounds, to: bar).minX))")
                }
                for c in v.subviews { walk(c, depth + 1) }
            }
            walk(bar, 0)
            return out.joined(separator: ",")
        }
        func refresh() {
            var host: UIViewController? = parent
            while let h = host, h.navigationController == nil { host = h.parent }
            guard let nav = (host ?? self).navigationController else { report.wrappedValue = "appears=\(appears) nav=none"; return }
            let top = nav.topViewController
            let item = top?.navigationItem
            let left = (item?.leftBarButtonItems ?? []).count, right = (item?.rightBarButtonItems ?? []).count
            let presented = nav.presentedViewController.map { String(describing: type(of: $0)) } ?? "-"
            let groups = "lg=\(item?.leadingItemGroups.count ?? -1) tg=\(item?.trailingItemGroups.count ?? -1) topIsItem=\(nav.navigationBar.topItem === item)"
            let bar = nav.navigationBar
            report.wrappedValue = "appears=\(appears) hidden=\(nav.isNavigationBarHidden) barAlpha=\(bar.alpha) axHidden=\(bar.accessibilityElementsHidden) left=\(left) right=\(right) \(groups) back=\(item?.hidesBackButton == true ? "hidden" : "shown") stack=\(nav.viewControllers.count) presented=\(presented) views=\(barViews(bar))"
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

import SwiftUI
import UIKit
import AVKit
import PDFKit

/// One thing a tool made, as the full-screen viewer shows it.
enum ViewerItem {
    case url(URL)
    case image(UIImage)
    case pdf(Data)

    var isVideo: Bool { if case .url(let u) = self { return ResultViewer.videoExts.contains(u.pathExtension.lowercased()) }; return false }
    var isPDF: Bool {
        switch self { case .pdf: return true; case .url(let u): return u.pathExtension.lowercased() == "pdf"; default: return false }
    }
    /// What Save / Share hand on: the file itself, or the bytes made into a named file.
    var keep: KeepItem? {
        switch self {
        case .url(let u): return .file(u)
        case .image(let i): return i.jpegData(compressionQuality: 0.92).map { .data($0, name: "Tenzy photo", ext: "jpg") }
        case .pdf(let d): return .data(d, name: "Tenzy document", ext: "pdf")
        }
    }
}

/// Every result, big: tap a result anywhere in Tenzy and it opens here full screen — pinch to zoom a photo, page
/// through a PDF, play a video — with ‹ › to step through a batch, "2 of 3", and Save / Share for the one you're on.
/// Done closes it and you're back on the result (Manan, 22 Nov: "give them a preview when they click on the image…
/// they can review each image… save it or share it. This applies to all the tools").
struct ResultViewer: View {
    static let videoExts: Set<String> = ["mp4", "mov", "m4v"]
    let items: [ViewerItem]
    @State var index: Int
    var tool: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $index) {
                    ForEach(items.indices, id: \.self) { i in
                        ViewerPage(item: items[i], active: i == index).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.black)
                .accessibilityIdentifier("viewer-pages")
                controls
            }
            .background(HandyColor.bg)
            .navigationTitle(items.count > 1 ? "\(index + 1) \(L("of")) \(items.count)" : L("Your result"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() }.accessibilityIdentifier("viewer-done") } }
        }
    }

    private var controls: some View {
        VStack(spacing: HandySpacing.s8) {
            if items.count > 1 {
                HStack {
                    step(-1, "chevron.left", L("Previous"))
                    Spacer()
                    Text("\(index + 1) \(L("of")) \(items.count)").font(HandyFont.bodyStrong.monospacedDigit())
                    Spacer()
                    step(1, "chevron.right", L("Next"))
                }
            }
            if let k = items[index].keep {
                KeepShare([k], tool: tool, record: false).id(index)
            }
        }
        .padding(.horizontal, HandySpacing.gutter).padding(.vertical, HandySpacing.s12)
        .background(HandyColor.bg)
    }

    private func step(_ d: Int, _ icon: String, _ label: String) -> some View {
        let to = index + d
        return Button { withAnimation { index = to } } label: {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).frame(width: 52, height: 44)
                .background(HandyColor.surface, in: Capsule())
        }
        .buttonStyle(.plain).foregroundStyle(HandyColor.textPrimary)
        .disabled(!items.indices.contains(to)).opacity(items.indices.contains(to) ? 1 : 0.35)
        .accessibilityLabel(label).accessibilityIdentifier(d < 0 ? "viewer-prev" : "viewer-next")
    }
}

/// One result filling the screen: zoomable photo, scrollable PDF, or a video that plays while it's the one shown.
private struct ViewerPage: View {
    let item: ViewerItem
    let active: Bool
    @State private var image: UIImage?
    @State private var player = AVPlayer()

    var body: some View {
        Group {
            if item.isVideo, case .url(let u) = item {
                VideoPlayer(player: player)
                    .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: u)) }
                    .onChange(of: active) { _, on in if on { player.play() } else { player.pause() } }
                    .onDisappear { player.pause() }
            } else if item.isPDF {
                PDFPreview(data: pdfData)
            } else if let image {
                ZoomableImage(image: image)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { image = await load() }
    }

    private var pdfData: Data {
        switch item { case .pdf(let d): return d; case .url(let u): return (try? Data(contentsOf: u)) ?? Data(); default: return Data() }
    }

    private func load() async -> UIImage? {
        switch item {
        case .image(let i): return i
        case .url(let u) where !item.isVideo && !item.isPDF:
            return await Task.detached { UIImage(contentsOfFile: u.path)?.resized(maxDimension: 2400) }.value
        default: return nil
        }
    }
}

/// A photo you can pinch, double-tap and pan — the way Photos does it.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let s = UIScrollView()
        s.minimumZoomScale = 1; s.maximumZoomScale = 5
        s.showsHorizontalScrollIndicator = false; s.showsVerticalScrollIndicator = false
        s.delegate = context.coordinator
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isAccessibilityElement = true
        iv.accessibilityLabel = L("Your result, full size")
        s.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: s.contentLayoutGuide.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: s.contentLayoutGuide.trailingAnchor),
            iv.topAnchor.constraint(equalTo: s.contentLayoutGuide.topAnchor),
            iv.bottomAnchor.constraint(equalTo: s.contentLayoutGuide.bottomAnchor),
            iv.widthAnchor.constraint(equalTo: s.frameLayoutGuide.widthAnchor),
            iv.heightAnchor.constraint(equalTo: s.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.imageView = iv
        let dbl = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        s.addGestureRecognizer(dbl)
        return s
    }
    func updateUIView(_ s: UIScrollView, context: Context) {
        if context.coordinator.imageView?.image !== image { context.coordinator.imageView?.image = image; s.zoomScale = 1 }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let s = g.view as? UIScrollView else { return }
            if s.zoomScale > 1 { s.setZoomScale(1, animated: true) }
            else {
                let p = g.location(in: imageView)
                s.zoom(to: CGRect(x: p.x - 60, y: p.y - 60, width: 120, height: 120), animated: true)
            }
        }
    }
}

/// A "see it full size" button in the corner of a result picture — a button rather than a tap on the picture, so it
/// never fights a tool's own hold-to-compare or drag. Opens the same full-screen viewer as everywhere else.
private struct FullSizeButton: ViewModifier {
    let image: UIImage?
    var tool = ""
    @State private var open = false
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if image != nil {
                    Button { open = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white).frame(width: 40, height: 40)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain).padding(8)
                    .accessibilityLabel(L("See it full size")).accessibilityIdentifier("full-size")
                }
            }
            .fullScreenCover(isPresented: $open) { if let image { ResultViewer(items: [.image(image)], index: 0, tool: tool) } }
    }
}

extension View {
    /// Adds the corner button that opens this result picture full screen, with Save and Share.
    func opensFullSize(_ image: UIImage?, tool: String = "") -> some View { modifier(FullSizeButton(image: image, tool: tool)) }
}

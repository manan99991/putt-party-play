import SwiftUI
import VisionKit
import PDFKit

/// Apple's own edge-detecting scanner, without digging through Notes. Output: multi-page PDF you can share.
struct DocScannerView: View {
    @State private var showScanner = false
    @State private var pdfURL: URL?
    @State private var pageCount = 0

    var body: some View {
        ToolPage(title: "Doc Scanner", subtitle: "Point at a page. Auto-crop, auto-flatten, multi-page PDF.") {
            Button { showScanner = true } label: { Label("Scan", systemImage: "doc.viewfinder").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(!VNDocumentCameraViewController.isSupported)
            if let pdfURL {
                Text("\(pageCount) page\(pageCount == 1 ? "" : "s") scanned").font(.headline)
                ShareLink(item: pdfURL) { Label("Share PDF", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerRep { images in
                showScanner = false
                guard !images.isEmpty else { return }
                let pdf = PDFDocument()
                for (i, img) in images.enumerated() { if let p = PDFPage(image: img) { pdf.insert(p, at: i) } }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Scan-\(Int(Date().timeIntervalSince1970)).pdf")
                pdf.write(to: url); pdfURL = url; pageCount = images.count
                Interstitials.shared.showIfReady()
            }.ignoresSafeArea()
        }
    }
}

private struct ScannerRep: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController { let v = VNDocumentCameraViewController(); v.delegate = context.coordinator; return v }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(done: done) }
    final class Coord: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(done: @escaping ([UIImage]) -> Void) { self.done = done }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { done([]) }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError e: Error) { done([]) }
    }
}

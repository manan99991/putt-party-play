import SwiftUI
import VisionKit
import CoreImage.CIFilterBuiltins

/// Scan any QR/barcode (live camera), or generate one: a link, plain text, or Wi‑Fi join code
/// (so guests tap-scan instead of typing your password).
struct QRToolsView: View {
    @State private var tab = 0
    @State private var scanned: String?
    @State private var showScanner = false
    // generator
    @State private var kind = 0
    @State private var text = ""
    @State private var ssid = ""
    @State private var password = ""
    @State private var qrImage: UIImage?

    var body: some View {
        ToolPage(title: "QR Tools", subtitle: "Scan codes, or make one to share a link or your Wi‑Fi.") {
            HStack(spacing: HandySpacing.s8) { HChip(text: "Scan", selected: tab == 0) { tab = 0 }; HChip(text: "Make", selected: tab == 1) { tab = 1 } }
            if tab == 0 {
                Button { showScanner = true } label: { Label("Open scanner", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity) }
                    .primaryButton().disabled(!DataScannerViewController.isSupported)
                if let s = scanned {
                    Text(s).font(HandyFont.body).textSelection(.enabled).cardStyle(padding: HandySpacing.s12)
                    HStack {
                        Button { UIPasteboard.general.string = s; ClipStore.add(s) } label: { Label("Copy", systemImage: "doc.on.doc") }.secondaryButton()
                        if let u = URL(string: s), u.scheme?.hasPrefix("http") == true { Link(destination: u) { Label("Open", systemImage: "safari") }.secondaryButton() }
                    }
                }
            } else {
                HStack(spacing: HandySpacing.s8) { HChip(text: "Link / text", selected: kind == 0) { kind = 0 }; HChip(text: "Wi‑Fi", selected: kind == 1) { kind = 1 } }
                if kind == 0 { TextField("https://… or any text", text: $text).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1)) }
                else {
                    TextField("Network name (SSID)", text: $ssid).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    SecureField("Password", text: $password).padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)).overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }
                Button { generate() } label: { Label("Make QR code", systemImage: "qrcode").frame(maxWidth: .infinity) }.primaryButton()
                if let qrImage {
                    Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).frame(maxWidth: .infinity)
                        .padding(HandySpacing.s24).background(.white, in: RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                    ShareLink(item: Image(uiImage: qrImage), preview: SharePreview("QR code", image: Image(uiImage: qrImage))) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) { ScannerSheet { scanned = $0; showScanner = false } }
    }

    private func generate() {
        let payload: String
        if kind == 0 { payload = text }
        else {
            func esc(_ s: String) -> String { s.replacingOccurrences(of: #"([\\;,":])"#, with: #"\\$1"#, options: .regularExpression) }
            payload = "WIFI:T:\(password.isEmpty ? "nopass" : "WPA");S:\(esc(ssid));P:\(esc(password));;"
        }
        guard !payload.isEmpty else { return }
        let f = CIFilter.qrCodeGenerator(); f.message = Data(payload.utf8); f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)), let cg = CIContext().createCGImage(out, from: out.extent) else { return }
        qrImage = UIImage(cgImage: cg)
    }
}

private struct ScannerSheet: View {
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            DataScannerRep(onResult: onResult).ignoresSafeArea()
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white).padding() }
        }
    }
}

private struct DataScannerRep: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced, isHighlightingEnabled: true)
        v.delegate = context.coordinator
        try? v.startScanning()
        return v
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(onResult: onResult) }
    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let onResult: (String) -> Void
        init(onResult: @escaping (String) -> Void) { self.onResult = onResult }
        func dataScanner(_ s: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            if case .barcode(let b) = added.first, let v = b.payloadStringValue { s.stopScanning(); onResult(v) }
        }
    }
}

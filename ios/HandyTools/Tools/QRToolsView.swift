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
            Picker("", selection: $tab) { Text("Scan").tag(0); Text("Make").tag(1) }.pickerStyle(.segmented)
            if tab == 0 {
                Button { showScanner = true } label: { Label("Open scanner", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!DataScannerViewController.isSupported)
                if let s = scanned {
                    Text(s).textSelection(.enabled).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Button { UIPasteboard.general.string = s; ClipStore.add(s) } label: { Label("Copy", systemImage: "doc.on.doc") }.buttonStyle(.bordered)
                        if let u = URL(string: s), u.scheme?.hasPrefix("http") == true { Link(destination: u) { Label("Open", systemImage: "safari") }.buttonStyle(.bordered) }
                    }
                }
            } else {
                Picker("Type", selection: $kind) { Text("Link / text").tag(0); Text("Wi‑Fi").tag(1) }.pickerStyle(.segmented)
                if kind == 0 { TextField("https://… or any text", text: $text).textFieldStyle(.roundedBorder) }
                else {
                    TextField("Network name (SSID)", text: $ssid).textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                }
                Button { generate() } label: { Label("Make QR code", systemImage: "qrcode").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
                if let qrImage {
                    Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).frame(maxWidth: .infinity)
                        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    ShareLink(item: Image(uiImage: qrImage), preview: SharePreview("QR code", image: Image(uiImage: qrImage))) { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
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

import SwiftUI
import VisionKit
import Vision
import PhotosUI
import UIKit

#if canImport(Translation)
import Translation
#endif

/// Capture — point the camera at anything with words or a code on it. Tap a line to grab it, or grab
/// everything in view; codes are decoded and turned into actions on sight. Then do the thing you
/// actually wanted: copy, translate, call the number, open the link, add the date, or ask what it means.
/// Live Text does half of this, three taps deep in Photos; here it's one screen and it chains.
struct CaptureView: View {
    @EnvironmentObject var store: StoreManager

    private struct Grab: Identifiable { let id = UUID(); let text: String; let code: String? }

    @State private var liveCounts = (text: 0, codes: 0)
    @State private var grabTrigger = 0
    @State private var paused = false
    @State private var grab: Grab?
    @State private var photoItem: PhotosPickerItem?
    @State private var busy = false
    @State private var errorText: String?
    @State private var translating = false
    @State private var aiAnswer = ""
    @State private var aiBusy = false

    private var cameraOK: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        ToolPage(title: "Capture", subtitle: "Point at text or a code. Tap a line to grab it, or grab everything — then copy, translate, call, open, or ask.") {
            if cameraOK {
                ZStack(alignment: .bottom) {
                    LiveCapture(grabTrigger: $grabTrigger, paused: $paused,
                                onCounts: { t, c in liveCounts = (t, c) },
                                onText: { s in show(text: s, code: nil) },
                                onCode: { s in show(text: s, code: s) })
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    HStack(spacing: HandySpacing.s8) {
                        if paused {
                            Button { paused = false; grab = nil; aiAnswer = "" } label: { Label("Scan again", systemImage: "arrow.clockwise") }.compactButton()
                        } else {
                            Button { grabTrigger += 1 } label: {
                                Label(liveCounts.text > 0 ? "Grab all text (\(liveCounts.text))" : "Looking for text…", systemImage: "text.viewfinder")
                            }.compactButton().disabled(liveCounts.text == 0)
                        }
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) { Image(systemName: "photo").frame(width: 36, height: 36) }.compactButton()
                    }
                    .padding(HandySpacing.s12)
                }
                Text(paused ? "Paused on what you grabbed." : "Tap any highlighted line to grab just that. Pinch to zoom.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose a photo with text or a code", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                }.secondaryButton()
                Text("The live camera reader needs a real iPhone (and camera access). Photos work everywhere.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }

            if busy { HStack { ProgressView(); Text("Reading…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            if let grab { result(grab) }
        }
        .onChange(of: photoItem) { _, item in readPhoto(item) }
        .onAppear { if Launch.sample, grab == nil { show(text: "SAMPLE 2026\nCall 415-555-0123 or visit https://example.com tomorrow at 7pm", code: nil) } }
        .modifier(TranslateSheet(isPresented: $translating, text: grab?.text ?? ""))
    }

    // MARK: result

    @ViewBuilder private func result(_ g: Grab) -> some View {
        if let code = g.code {
            QRResultCard(raw: code)
        } else {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                Text(g.text).font(HandyFont.body).textSelection(.enabled).lineLimit(12)
                let found = Detected.scan(g.text)
                if !found.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: HandySpacing.s8) { ForEach(found) { d in Link(destination: d.url) { Label(d.label, systemImage: d.icon) }.compactButton() } }
                    }
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { UIPasteboard.general.string = g.text; ClipStore.add(g.text); HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }.primaryButton()
                    Button { translating = true } label: { Label("Translate", systemImage: "character.bubble").frame(maxWidth: .infinity) }.secondaryButton()
                }
                HStack(spacing: HandySpacing.s8) {
                    ShareLink(item: g.text) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
                    if AIEngine.isAvailable {
                        Button { ask(g.text) } label: { HStack { if aiBusy { ProgressView() }; Label("What does this mean?", systemImage: "sparkles") } }.compactButton().disabled(aiBusy)
                    }
                    Spacer()
                }
                if !aiAnswer.isEmpty {
                    Text(aiAnswer).font(HandyFont.body).textSelection(.enabled)
                        .padding(HandySpacing.s12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(HandyColor.accentSoft, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                }
            }
            .cardStyle(padding: HandySpacing.s16)
        }
    }

    // MARK: actions

    private func show(text: String, code: String?) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        grab = Grab(text: t, code: code); aiAnswer = ""; errorText = nil; paused = true
        HandyHaptics.success()
    }

    private func readPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        busy = true; errorText = nil
        Task {
            guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { await MainActor.run { busy = false; errorText = "Couldn't load that photo." }; return }
            if let code = Self.barcode(in: img) { await MainActor.run { busy = false; show(text: code, code: code) }; return }
            let text = await AIEngine.recognizeText(img)
            await MainActor.run {
                busy = false
                if text.isEmpty { errorText = "No text or code found in that photo." } else { show(text: text, code: nil) }
            }
        }
    }

    static func barcode(in image: UIImage) -> String? {
        // Normalise what the detector sees: upright, between ~800 and 1600 px (tiny screenshots and
        // generated codes get enlarged crisply), with a white quiet zone — screenshots rarely have one.
        var src = image.normalizedUp().resized(maxDimension: 1600)
        let longest = max(src.size.width, src.size.height)
        if longest < 800 {
            let k = (800 / longest).rounded(.up)
            let size = CGSize(width: src.size.width * k, height: src.size.height * k)
            let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
            let base = src
            src = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
                c.cgContext.interpolationQuality = .none
                base.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        let pad = max(32, src.size.width * 0.08)
        let size = CGSize(width: src.size.width + pad * 2, height: src.size.height + pad * 2)
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let padded = UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            src.draw(in: CGRect(x: pad, y: pad, width: src.size.width, height: src.size.height))
        }
        guard let cg = padded.cgImage else { return nil }
        for revision in [VNDetectBarcodesRequest.currentRevision, VNDetectBarcodesRequestRevision1] {
            let req = VNDetectBarcodesRequest()
            req.revision = revision
            try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
            if let v = req.results?.compactMap(\.payloadStringValue).first { return v }
        }
        return nil
    }

    private func ask(_ text: String) {
        guard Usage.use("ai", limit: Limits.freeAiPerDay) else { errorText = "You've used today's \(Limits.freeAiPerDay) free AI answers."; return }
        aiBusy = true; aiAnswer = ""
        Task { @MainActor in
            defer { aiBusy = false }
            do {
                aiAnswer = try await AIEngine.run(instructions: "You explain text a person just photographed — a sign, label, menu, form, notice, or message. In 2–4 short sentences say what it is and what matters for them. Plain words, no preamble.", prompt: text)
            } catch { errorText = error.localizedDescription }
        }
    }
}

// MARK: - live reader

/// DataScanner reading text and codes at once. Tapping a line grabs it; `grabTrigger` grabs every
/// visible line in reading order; `paused` freezes the feed on the result.
private struct LiveCapture: UIViewControllerRepresentable {
    @Binding var grabTrigger: Int
    @Binding var paused: Bool
    let onCounts: (Int, Int) -> Void
    let onText: (String) -> Void
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.text(), .barcode()], qualityLevel: .balanced,
                                          recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
                                          isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        v.delegate = context.coordinator
        try? v.startScanning()
        return v
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        let c = context.coordinator
        if grabTrigger != c.lastTrigger {
            c.lastTrigger = grabTrigger
            let lines = c.items.compactMap { item -> (String, CGPoint)? in
                if case .text(let t) = item { return (t.transcript, item.bounds.topLeft) } else { return nil }
            }.sorted { a, b in abs(a.1.y - b.1.y) > 12 ? a.1.y < b.1.y : a.1.x < b.1.x }
            let joined = lines.map(\.0).joined(separator: "\n")
            if !joined.isEmpty { DispatchQueue.main.async { onText(joined) } }
        }
        if paused, vc.isScanning { vc.stopScanning() }
        if !paused, !vc.isScanning { try? vc.startScanning() }
    }

    func makeCoordinator() -> Coord { Coord(onCounts: onCounts, onText: onText, onCode: onCode) }

    final class Coord: NSObject, DataScannerViewControllerDelegate {
        var items: [RecognizedItem] = []
        var lastTrigger = 0
        let onCounts: (Int, Int) -> Void, onText: (String) -> Void, onCode: (String) -> Void
        init(onCounts: @escaping (Int, Int) -> Void, onText: @escaping (String) -> Void, onCode: @escaping (String) -> Void) {
            self.onCounts = onCounts; self.onText = onText; self.onCode = onCode
        }
        private func sync(_ all: [RecognizedItem]) {
            items = all
            var t = 0, c = 0
            for i in all { if case .text = i { t += 1 } else { c += 1 } }
            onCounts(t, c)
        }
        func dataScanner(_ s: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            sync(allItems)
            for i in added { if case .barcode(let b) = i, let v = b.payloadStringValue { onCode(v); return } }
        }
        func dataScanner(_ s: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) { sync(allItems) }
        func dataScanner(_ s: DataScannerViewController, didRemove removed: [RecognizedItem], allItems: [RecognizedItem]) { sync(allItems) }
        func dataScanner(_ s: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let t): onText(t.transcript)
            case .barcode(let b): if let v = b.payloadStringValue { onCode(v) }
            @unknown default: break
            }
        }
    }
}

// MARK: - detected data

/// Phone numbers, links, emails, addresses and dates in grabbed text, each with the one-tap action.
struct Detected: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let url: URL

    static func scan(_ text: String) -> [Detected] {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.address.rawValue | NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        var out: [Detected] = []
        for m in det.matches(in: text, range: NSRange(text.startIndex..., in: text)).prefix(12) {
            switch m.resultType {
            case .phoneNumber:
                if let n = m.phoneNumber, let u = URL(string: "tel:" + n.filter { "+0123456789".contains($0) }) { out.append(Detected(label: "Call \(n)", icon: "phone", url: u)) }
            case .link:
                if let u = m.url {
                    if u.scheme == "mailto" { out.append(Detected(label: "Email \(u.absoluteString.replacingOccurrences(of: "mailto:", with: ""))", icon: "envelope", url: u)) }
                    else { out.append(Detected(label: "Open \(u.host ?? u.absoluteString)", icon: "safari", url: u)) }
                }
            case .address:
                let raw = (text as NSString).substring(with: m.range)
                if let q = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let u = URL(string: "maps://?q=\(q)") { out.append(Detected(label: "Map \(raw.prefix(24))", icon: "map", url: u)) }
            case .date:
                if let d = m.date, let u = URL(string: "calshow:\(d.timeIntervalSinceReferenceDate)") {
                    let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = m.duration > 0 || Calendar.current.component(.hour, from: d) != 12 ? .short : .none
                    out.append(Detected(label: "Calendar · \(f.string(from: d))", icon: "calendar", url: u))
                }
            default: break
            }
        }
        return out
    }
}

/// System translation sheet, compiled out on SDKs without the framework.
private struct TranslateSheet: ViewModifier {
    @Binding var isPresented: Bool
    let text: String
    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 17.4, *) { content.translationPresentation(isPresented: $isPresented, text: text) } else { content }
        #else
        content
        #endif
    }
}

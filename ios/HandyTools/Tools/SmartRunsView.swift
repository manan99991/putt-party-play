import SwiftUI
import UniformTypeIdentifiers
import Photos
import UserNotifications
import AVKit

/// Smart autoruns (25 Nov): the end-of-day jobs a personal assistant would do. Switch one on, pick once or twice a
/// day and the time, and Test run shows exactly what it would do right now. What it finds waits here for a look —
/// nothing is added, sent or deleted without the person seeing it first.
struct SmartRunsView: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pickingFolder = false
    @State private var note: String?
    @State private var photosDenied = false
    @State private var seeded = false   // UI tests: the test media is in the library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s16) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }
                        .accessibilityIdentifier("page-back")
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Smart autoruns")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                    Text(L("Tenzy does the end-of-day jobs for you, on your phone. You look it over, then it's done."))
                        .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                if seeded { Text(verbatim: "ready").font(.system(size: 1)).opacity(0.01).accessibilityIdentifier("seed-done") }
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("smartruns-note") }
                if photosDenied {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("To find today's receipts, Tenzy needs to look through your photos. It reads them on this phone only — nothing is uploaded."))
                            .font(HandyFont.caption).fixedSize(horizontal: false, vertical: true)
                        Button { Permission.openSettings() } label: { Label(L("Allow Full Access in Settings"), systemImage: "gearshape") }.textButton()
                    }.cardStyle(padding: HandySpacing.s12)
                }
                if let k = store.working { workingCard(k) }
                ForEach(SmartRunStore.built) { k in card(k) }
                NavigationLink(value: "myreminders") {
                    Label(L("Or a simple reminder at a time you pick"), systemImage: "bell.badge").frame(maxWidth: .infinity, alignment: .leading)
                }.secondaryButton().accessibilityIdentifier("smartruns-reminder")
                Text(L("iPhone decides when apps may work in the background, usually overnight while charging. If the work isn't done by your time, tapping the notification finishes it."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartruns")
        .task {
            if Launch.uitest, Launch.args.contains("-seedreceipt") { await Self.seedReceipt() }
            Self.seedDrives()
            if Launch.uitest, Launch.args.contains("-seedheavyvideo") { await Self.seedHeavyVideo(); seeded = true }
            await store.runDue()
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { r in
            if case .success(let u) = r {
                note = SmartReceipts.remember(folder: u) ? "\(L("Tenzy will also read the PDFs saved in")) \u{201C}\(u.lastPathComponent)\u{201D}." : L("That folder couldn't be opened. Try another one.")
            }
        }
    }

    /// UI tests: a 12-second 1080p clip saved wastefully (a very high H.264 bitrate), the way some cameras and apps
    /// save video — the case where HEVC saves a lot and looks the same.
    static func seedHeavyVideo() async {
        let key = "uitest.seededHeavy"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("heavy-\(UUID().uuidString).mp4")
        let w = 1920, h = 1080, fps: Int32 = 30, frames = 360
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 45_000_000, AVVideoMaxKeyFrameIntervalKey: 1,
                                              AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: .zero)
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 2_000_000) }
            guard let pool = adaptor.pixelBufferPool else { break }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let pb else { break }
            CVPixelBufferLockBaseAddress(pb, [])
            if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                let t = CGFloat(i) / CGFloat(frames)
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(hue: t, saturation: 0.6, brightness: 0.9, alpha: 1).cgColor,
                                                                                         UIColor(hue: 1 - t, saturation: 0.7, brightness: 0.5, alpha: 1).cgColor] as CFArray, locations: nil)!
                ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h), options: [])
                for k in 0..<12 {
                    let x = CGFloat(w) * (0.5 + 0.4 * sin(t * 6.28 * 2 + CGFloat(k))), y = CGFloat(h) * (0.5 + 0.4 * cos(t * 6.28 + CGFloat(k) * 0.7))
                    ctx.setFillColor(UIColor(hue: CGFloat(k) / 12, saturation: 0.8, brightness: 1, alpha: 0.9).cgColor)
                    ctx.fillEllipse(in: CGRect(x: x - 90, y: y - 90, width: 180, height: 180))
                }
            }
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let r = PHAssetCreationRequest.forAsset()
                r.addResource(with: .video, fileURL: url, options: nil)
                r.creationDate = Date()   // taken now, as a camera clip would be
            }
            UserDefaults.standard.set(true, forKey: key)
        } catch { SmartVideos.note("test clip not saved: \(error.localizedDescription)") }
    }

    /// UI tests: two drives earlier today, about 4.2 and 1.3 miles.
    static func seedDrives() {
        guard Launch.uitest, Launch.args.contains("-seeddrives"), DriveStore.all().isEmpty else { return }
        let now = Date()
        DriveStore.add(DriveStore.Drive(start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-6600), fromLat: 41.7508, fromLng: -88.1535,
                                        toLat: 41.7858, toLng: -88.1472, metres: 6760))
        DriveStore.add(DriveStore.Drive(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-3240), fromLat: 41.7858, fromLng: -88.1472,
                                        toLat: 41.7700, toLng: -88.1600, metres: 2090))
        SmartRunStore.shared.objectWillChange.send()
    }

    /// UI tests: a real-looking shop receipt saved to the library (taken now), so a Test run has something to read.
    static func seedReceipt() async {
        let key = "uitest.seededReceipt"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let lines = ["CORNER MARKET", "1420 Ogden Ave, Naperville IL", "11/25/2026  12:41 PM", "", "Milk 2%           4.29", "Sourdough Bread   5.49",
                     "Bananas           1.86", "", "SUBTOTAL         11.64", "TAX               0.73", "TOTAL            12.37", "", "VISA ****4821    12.37", "THANK YOU"]
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1600), format: f).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 1600))
            let font = UIFont.monospacedSystemFont(ofSize: 44, weight: .medium)
            for (i, l) in lines.enumerated() {
                (l as NSString).draw(at: CGPoint(x: 90, y: 120 + CGFloat(i) * 92), withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: img) }
            UserDefaults.standard.set(true, forKey: key)
        } catch {}
    }

    private func workingCard(_ k: SmartRuns.Kind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { BusySpinner(); Text(L(store.progress.what)).font(HandyFont.caption) }
            ProgressView(value: store.progress.share).tint(HandyColor.accent)
            if let s = store.started {
                TimelineView(.periodic(from: s, by: 1)) { ctx in
                    let gone = ctx.date.timeIntervalSince(s)
                    let left = store.progress.share > 0.05 ? gone / store.progress.share - gone : nil
                    Text(left.map { "\(L("About")) \(Int($0.rounded(.up)))s \(L("left"))" } ?? "\(Int(gone))s")
                        .font(HandyFont.micro.monospacedDigit()).foregroundStyle(HandyColor.textSecondary)
                }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityIdentifier("smartrun-working")
    }

    private func card(_ k: SmartRuns.Kind) -> some View {
        let p = store.plan(k)
        return VStack(alignment: .leading, spacing: HandySpacing.s12) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                Image(systemName: k.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(Color(hex: k.hex).gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L(k.title)).font(HandyFont.bodyStrong)
                    Text(L(k.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Toggle(isOn: Binding(get: { p.on }, set: { on in Task { await turn(k, on: on) } })) { Text(L("Do this for me")).font(HandyFont.bodyStrong) }
                .tint(HandyColor.accent).accessibilityIdentifier("smartrun-on-\(k.rawValue)")
            if p.on {
                Picker(L("How often"), selection: Binding(get: { p.twice }, set: { var q = p; q.twice = $0; store.set(k, q) })) {
                    Text(L("Once a day")).tag(false); Text(L("Twice a day")).tag(true)
                }.pickerStyle(.segmented)
                DatePicker(L(p.twice ? "First time" : "Time"), selection: Binding(get: {
                    Calendar.current.date(from: DateComponents(hour: p.hour, minute: p.minute)) ?? Date()
                }, set: { d in var q = p; let c = Calendar.current.dateComponents([.hour, .minute], from: d); q.hour = c.hour ?? 20; q.minute = c.minute ?? 0; store.set(k, q) }),
                           displayedComponents: .hourAndMinute).font(HandyFont.body)
                Text(p.times.map { ChainSchedule.clock(hour: $0.hour, minute: $0.minute, uses24h: false) }.joined(separator: " " + L("and") + " "))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.accent)
            }
            if k == .drives {
                Text(L(AutoPark.isOn ? "Uses Find my car's drive detection, which is on." : "Uses Find my car's drive detection — switching this on turns it on."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if k == .readyToPost {
                // The look every clip gets — shown as chips that wrap, never a sideways scroller.
                Text(L("Your look")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: 6) {
                    ForEach(SmartPosts.looks, id: \.self) { id in
                        let c = VideoFX.looks.first { $0.id == id }
                        HChip(text: "\(c?.emoji ?? "") \(L(c?.name ?? id))", selected: (p.look ?? "vivid") == id) { var q = p; q.look = id; store.set(k, q) }
                            .accessibilityIdentifier("smartpost-look-\(id)")
                    }
                }
            }
            if k == .receipts {
                Button { pickingFolder = true } label: {
                    Label(SmartReceipts.folder.map { "\(L("PDFs from")) \($0.lastPathComponent)" } ?? L("Also read PDFs from a folder…"), systemImage: "folder")
                }.textButton().accessibilityIdentifier("smartrun-folder")
            }
            HStack(spacing: HandySpacing.s8) {
                Button { Task { await testRun(k) } } label: { Label(L("Test run"), systemImage: "play.circle").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(store.working != nil).accessibilityIdentifier("smartrun-test-\(k.rawValue)")
                if store.waitingCount(k) > 0 {
                    NavigationLink(value: k == .drives ? "smartdrives" : k == .heavyVideos ? "smartvideos" : k == .readyToPost ? "smartposts" : "smartreceipts") {
                        Text("\(L("Check")) \(store.waitingCount(k))").frame(maxWidth: .infinity)
                    }.primaryButton().accessibilityIdentifier("smartrun-check-\(k.rawValue)")
                }
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private func photosOK() async -> Bool {
        var s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if s == .notDetermined { s = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        photosDenied = !(s == .authorized || s == .limited)
        return !photosDenied
    }

    private func turn(_ k: SmartRuns.Kind, on: Bool) async {
        var p = store.plan(k)
        if on, k == .drives {
            // Drives come from Find my car's drive detection: switching this on switches that on too.
            if !AutoPark.isOn { AutoPark.shared.turnOn() }
        } else if on {
            guard await photosOK() else { return }
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if !granted { note = L("Notifications are off for Tenzy, so it can't tell you when this is ready. Turn them on in Settings › Tenzy › Notifications.") }
        }
        p.on = on
        store.set(k, p)
        if on { note = (note ?? "") .isEmpty ? L("Set. Tap Test run to see what it does right now.") : note }
    }

    private func testRun(_ k: SmartRuns.Kind) async {
        if k == .drives {
            let n = store.waitingCount(.drives)
            note = n > 0 ? "\(L("Test run found")) \(n) \(L(n == 1 ? "drive" : "drives")). \(L("Tap Check to log the ones for work."))"
                         : (AutoPark.isOn ? L("Test run worked: no drives yet this week. Your next drive shows up here once you park.")
                                          : L("Switch this on first — it uses Find my car's drive detection."))
            HandyHaptics.success(); return
        }
        guard await photosOK() else { return }
        let before = store.waitingCount(k)
        await store.run(k, test: true)
        let found = store.waitingCount(k) - before
        if k == .readyToPost {
            note = found > 0 ? "\(L("Test run made")) \(found) \(L(found == 1 ? "clip ready to post" : "clips ready to post")). \(L("Tap Check to watch them."))"
                             : L("Test run worked: no clips from the last 24 hours between 4 seconds and 3 minutes.")
        } else if k == .heavyVideos {
            note = found > 0 ? "\(L("Test run made")) \(found) \(L(found == 1 ? "video smaller" : "videos smaller")). \(L("Tap Check to compare before anything changes."))"
                             : L("Test run worked: no video from the last 24 hours could be made noticeably smaller without losing quality.")
                               + (Launch.uitest ? " [" + SmartVideos.trail.joined(separator: " | ") + "]" : "")
        } else {
            note = found > 0 ? "\(L("Test run found")) \(found) \(L(found == 1 ? "receipt" : "receipts")). \(L("Check them before they're added."))"
                             : L("Test run worked: no receipts in your photos or PDFs from the last 24 hours.")
        }
        HandyHaptics.success()
    }
}

/// The receipts the autorun found, each as it will go into the sheet. Fix anything marked, then add them all.
struct SmartReceiptsReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var done: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Today's receipts")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                let file = (RunningList.target(pattern: RunningList.defaultName) as NSString).deletingPathExtension
                Text("\(L("Check each one, then add them to")) \u{201C}\(file)\u{201D}.")
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                if store.receipts.isEmpty && done == nil {
                    EmptyState(icon: "receipt", line: "Nothing waiting", sub: "New receipts show up here after the next run.")
                }
                ForEach(store.receipts) { e in ReceiptEntryCard(entry: e) }
                let ready = store.receipts.filter(\.ready).count
                if ready > 0 {
                    Button {
                        let r = store.addReady()
                        done = "\(r.added) \(L(r.added == 1 ? "receipt added to" : "receipts added to")) \u{201C}\(r.sheet)\u{201D}" + (r.already > 0 ? ". \(r.already) \(L("were already in it.")) " : ".")
                        HandyHaptics.success()
                    } label: { Text("\(L("Add")) \(ready) \(L("to my sheet"))").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smartreceipts-add")
                }
                if done != nil {
                    NavigationLink(value: "sheets") { Label(L("Open my sheets"), systemImage: "tablecells").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartreceipts")
    }
}

/// One found receipt: where it came from, the fields that go into the sheet (shop and total editable, anything
/// unsure marked), and why it's held back if it is.
private struct ReceiptEntryCard: View {
    let entry: SmartReceipts.Entry
    @ObservedObject private var store = SmartRunStore.shared
    @State private var shop = ""
    @State private var total = ""

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Label(L(entry.from.hasPrefix("PDF") ? "PDF" : entry.from), systemImage: entry.from.hasPrefix("PDF") ? "doc.richtext" : "photo")
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                if entry.from.hasPrefix("PDF: ") { Text(String(entry.from.dropFirst(5))).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(1) }
                Spacer()
                Button(role: .destructive) { store.drop(entry.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }
                    .accessibilityLabel(L("Not a business receipt — leave it out"))
            }
            TextField(L("Shop"), text: $shop).font(HandyFont.cardTitle)
                .padding(4).background(entry.unsure.contains("shop") ? HandyColor.amber.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .onSubmit(save)
            HStack {
                Text(entry.date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? L("No date on it — the day it was taken is used"))
                    .font(HandyFont.caption).padding(4)
                    .background(entry.unsure.contains("date") ? HandyColor.amber.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                Text("· \(L(entry.category))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                Text(entry.currency).font(HandyFont.cardTitle)
                TextField("0.00", text: $total).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(HandyFont.cardTitle.monospacedDigit()).frame(maxWidth: 110)
                    .padding(4).background(entry.unsure.contains("total") ? HandyColor.amber.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .onSubmit(save)
            }
            if let t = entry.tax { Text("\(L("Tax")) \(entry.currency)\(String(format: "%.2f", t))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            if !entry.lines.isEmpty {
                Text(entry.lines.prefix(4).joined(separator: " · ") + (entry.lines.count > 4 ? " …" : ""))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
            }
            if let b = entry.block {
                Label(L(b), systemImage: "exclamationmark.triangle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.amber).fixedSize(horizontal: false, vertical: true)
                Toggle(isOn: Binding(get: { entry.confirmed }, set: { var e = entry; e.confirmed = $0; store.update(e) })) {
                    Text(L("I've checked it against the receipt, add it as shown")).font(HandyFont.caption)
                }.tint(HandyColor.amber)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(entry.block == nil ? .clear : HandyColor.amber, lineWidth: 1.5))
        .onAppear { shop = entry.merchant; total = entry.total.map { String(format: "%.2f", $0) } ?? "" }
        .onChange(of: shop) { _, _ in save() }
        .onChange(of: total) { _, _ in save() }
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartreceipt-card")
    }

    private func save() {
        var e = entry
        e.merchant = shop.trimmingCharacters(in: .whitespaces)
        e.total = Double(total.replacingOccurrences(of: ",", with: "."))
        store.update(e)
    }
}


/// The drives waiting for a look: when, from where to where, how far. Mark each as work, medical, charity or personal;
/// the work ones (and medical, charity) go into the mileage log with the IRS rate.
struct SmartDrivesReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purpose: [UUID: Mileage.Purpose?] = [:]
    @State private var miles: [UUID: String] = [:]
    @State private var why: [UUID: String] = [:]
    @State private var places: [UUID: (String, String)] = [:]
    @State private var done: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Today's drives")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                Text(L("Tap what each drive was for. Personal drives are left out of the log."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                let list = store.drives
                if list.isEmpty && done == nil {
                    EmptyState(icon: "car.fill", line: "No drives waiting", sub: "Drives show up here after you park.")
                }
                ForEach(list) { d in card(d) }
                if !list.isEmpty {
                    let logged = list.filter { (purpose[$0.id] ?? nil) != nil }.count
                    Button {
                        let picks = Dictionary(uniqueKeysWithValues: list.map { d in
                            (d.id, (purpose: purpose[d.id] ?? nil, miles: Double((miles[d.id] ?? "").replacingOccurrences(of: ",", with: ".")) ?? d.miles, why: why[d.id] ?? ""))
                        })
                        let n = store.logDrives(picks, places: places)
                        done = n == 0 ? L("Done. Nothing was logged — all personal.") : "\(n) \(L(n == 1 ? "drive logged in your mileage." : "drives logged in your mileage."))"
                        HandyHaptics.success()
                    } label: { Text(logged == 0 ? L("Done — all personal") : "\(L("Log")) \(logged) \(L(logged == 1 ? "drive" : "drives"))").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smartdrives-log")
                }
                if done != nil {
                    NavigationLink(value: "mileage") { Label(L("Open Business Miles"), systemImage: "car.fill").frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartdrives")
        .onAppear { SmartRunsView.seedDrives() }
        .task {
            for d in store.drives where places[d.id] == nil {
                let a = await DrivePlaces.name(lat: d.fromLat, lng: d.fromLng), b = await DrivePlaces.name(lat: d.toLat, lng: d.toLng)
                places[d.id] = (a, b)
            }
        }
    }

    private func card(_ d: DriveStore.Drive) -> some View {
        let p = purpose[d.id] ?? nil
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text("\(d.start.formatted(date: .omitted, time: .shortened)) – \(d.end.formatted(date: .omitted, time: .shortened))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                TextField("0.0", text: Binding(get: { miles[d.id] ?? String(format: "%.1f", d.miles) }, set: { miles[d.id] = $0 }))
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).font(HandyFont.cardTitle.monospacedDigit()).frame(maxWidth: 80)
                    .accessibilityIdentifier("smartdrive-miles")
                Text(L("mi")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            let pl = places[d.id]
            Text(pl.map { "\($0.0.isEmpty ? L("Start") : $0.0) → \($0.1.isEmpty ? L("End") : $0.1)" } ?? L("Finding the places…"))
                .font(HandyFont.bodyStrong).fixedSize(horizontal: false, vertical: true)
            HandyFlow(spacing: 6) {   // wraps on a narrow phone, never scrolls sideways
                ForEach(Mileage.Purpose.allCases) { k in
                    HChip(text: L(k.title), selected: p == k) { purpose[d.id] = p == k ? .some(nil) : .some(k) }
                        .accessibilityIdentifier("smartdrive-\(k.rawValue)")
                }
                HChip(text: L("Personal"), selected: purpose[d.id] != nil && p == nil) { purpose[d.id] = .some(nil) }
            }
            if p != nil {
                TextField(L("What for (optional) — e.g. client visit"), text: Binding(get: { why[d.id] ?? "" }, set: { why[d.id] = $0 }))
                    .font(HandyFont.caption).padding(8).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartdrive-card")
    }
}


/// The smaller copies a run made, each with how much it saves and a frame-by-frame check that it looks the same. Save
/// them to Photos, then — only if you want — delete the originals through iPhone's own prompt.
struct SmartVideosReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var playing: URL?
    @State private var done: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Smaller videos")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                let total = store.videos.map(\.saving).reduce(0, +)
                if !store.videos.isEmpty {
                    Text("\(L("Saves")) \(SmartVideos.bytes(total)) — \(L("same size picture, same frame rate, checked frame by frame."))")
                        .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.accent).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("smartvideos-total")
                }
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                if store.videos.isEmpty && done == nil {
                    EmptyState(icon: "film", line: "Nothing waiting", sub: "Heavy videos show up here after the next run.")
                }
                ForEach(store.videos) { r in row(r) }
                if busy { HStack { BusySpinner(); Text(L("Saving to Photos…")).font(HandyFont.caption) } }
                let unsaved = store.videos.filter { !$0.saved }
                if !unsaved.isEmpty {
                    Button {
                        busy = true
                        Task {
                            let n = await store.saveVideos(Set(unsaved.map(\.id)))
                            busy = false
                            done = "\(n) \(L(n == 1 ? "smaller copy saved to Photos, with its original date and place." : "smaller copies saved to Photos, with their original dates and places."))"
                            HandyHaptics.success()
                        }
                    } label: { Text("\(L("Save")) \(unsaved.count) \(L(unsaved.count == 1 ? "smaller copy" : "smaller copies"))").frame(maxWidth: .infinity) }
                        .primaryButton().disabled(busy).accessibilityIdentifier("smartvideos-save")
                }
                let saved = store.videos.filter(\.saved)
                if !saved.isEmpty {
                    Button(role: .destructive) {
                        Task {
                            let ok = await store.deleteOriginals()
                            done = ok ? "\(L("Originals deleted. iPhone keeps them in Recently Deleted for 30 days; empty it there to get the space back now."))"
                                      : L("The originals were kept.")
                        }
                    } label: { Text("\(L("Delete the")) \(saved.count) \(L(saved.count == 1 ? "original" : "originals")) · \(L("frees")) \(SmartVideos.bytes(saved.map(\.saving).reduce(0, +)))").frame(maxWidth: .infinity) }
                        .secondaryButton().accessibilityIdentifier("smartvideos-delete")
                    Button { store.keepOriginals(); done = L("Kept both. The smaller copies are in Photos too.") } label: { Text(L("Keep the originals too")) }.textButton()
                    Text(L("iPhone asks before anything is deleted."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartvideos")
        .sheet(item: Binding(get: { playing.map { PlayURL(url: $0) } }, set: { playing = $0?.url })) { p in
            VideoPlayer(player: AVPlayer(url: p.url)).ignoresSafeArea()
        }
    }

    private func row(_ r: SmartVideos.Result) -> some View {
        let url = SmartVideos.folder.appendingPathComponent(r.file)
        return HStack(spacing: HandySpacing.s12) {
            Button { playing = url } label: {
                ZStack {
                    VideoThumb(url: url).frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle())
                    Image(systemName: "play.circle.fill").font(.system(size: 26)).foregroundStyle(.white).shadow(radius: 2)
                }
            }.buttonStyle(.plain).accessibilityLabel(L("Play the smaller copy"))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(SmartVideos.bytes(r.before)) → \(SmartVideos.bytes(r.after))").font(HandyFont.bodyStrong).monospacedDigit()
                Text("\(L("Saves")) \(SmartVideos.bytes(r.saving)) · \(SocialPost.clock(r.seconds))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Label(L("Looks the same — 7 frames checked"), systemImage: "checkmark.seal").font(HandyFont.micro).foregroundStyle(HandyColor.success)
                if r.saved { Label(L("Saved to Photos"), systemImage: "checkmark.circle.fill").font(HandyFont.micro).foregroundStyle(HandyColor.accent) }
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartvideo-row")
    }
}

/// The clips a run made ready to post: watch each, then save it to Photos and open the app to post it.
struct SmartPostsReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var saving: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Ready to post")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                Text(L("Tall 9:16, your look, sound kept. Watch each one, then save it and post it from the app."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if store.posts.isEmpty {
                    EmptyState(icon: "sparkles.tv", line: "Nothing waiting", sub: "Today's best clips show up here after the next run.")
                }
                ForEach(store.posts) { r in card(r) }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartposts")
    }

    private func card(_ r: SmartPosts.Result) -> some View {
        let url = SmartPosts.folder.appendingPathComponent(r.file)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            // The finished clip itself, playing in place: what you see is what gets posted.
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(9.0 / 16.0, contentMode: .fit).frame(maxHeight: 420).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).contentShape(Rectangle())
                .accessibilityIdentifier("smartpost-player")
                .accessibilityValue(Launch.uitest ? (r.size.map { "\($0[0])x\($0[1])" } ?? "unknown") : "")
            HStack {
                Text("\(SocialPost.clock(r.seconds)) · \(L(VideoFX.looks.first { $0.id == r.look }?.name ?? r.look))")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                Button(role: .destructive) { store.dropPost(r.id) } label: { Image(systemName: "trash").foregroundStyle(HandyColor.textSecondary) }
                    .accessibilityLabel(L("Not this one"))
            }
            if r.saved {
                Label(L("In Photos — open the app to post it"), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
                HandyFlow(spacing: 6) {
                    ForEach(["reels", "tiktok", "shorts"], id: \.self) { id in
                        if let p = SocialPost.platform(id), let link = SocialPost.openURL(p, assetID: r.savedID) {
                            Button { openURL(link) } label: { Label(p.name, systemImage: p.icon) }.secondaryButton()
                        }
                    }
                }
            } else {
                Button {
                    saving = r.id
                    Task { _ = await store.savePost(r.id); saving = nil; HandyHaptics.success() }
                } label: {
                    Label(saving == r.id ? L("Saving…") : L("Save to Photos to post"), systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }.primaryButton().disabled(saving != nil).accessibilityIdentifier("smartpost-save")
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartpost-card")
    }
}

private struct PlayURL: Identifiable { let url: URL; var id: String { url.path } }

/// A still from a video, for a list row.
private struct VideoThumb: View {
    let url: URL
    @State private var img: UIImage?
    var body: some View {
        ZStack { HandyColor.surface; if let img { Image(uiImage: img).resizable().scaledToFill() } }
            .task(id: url) { img = await VideoEngine.thumbnail(url, at: 0.5, maxDim: 300) }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import Photos
import UserNotifications
import AVKit
import MessageUI
import Speech
import PDFKit

/// Smart autoruns (25 Nov): the end-of-day jobs a personal assistant would do. Switch one on, pick once or twice a
/// day and the time, and Test run shows exactly what it would do right now. What it finds waits here for a look —
/// nothing is added, sent or deleted without the person seeing it first.
struct SmartRunsView: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pickingFolder = false
    @State private var pickingMemoFolder = false
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
            if Launch.uitest, Launch.args.contains("-seedcard") { await Self.seedCard(); seeded = true }
            if Launch.uitest, Launch.args.contains("-seedpaper") { await Self.seedPaper(); seeded = true }
            await store.runDue()
        }
        .fileImporter(isPresented: $pickingMemoFolder, allowedContentTypes: [.folder]) { r in
            if case .success(let u) = r {
                note = SmartVoice.remember(folder: u) ? "\(L("Tenzy will write up the voice memos saved in")) \u{201C}\(u.lastPathComponent)\u{201D}." : L("That folder couldn't be opened. Try another one.")
            }
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

    /// UI tests: a business card photographed today.
    static func seedCard() async {
        let key = "uitest.seededCard"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 800), format: f).image { ctx in
            UIColor(white: 0.97, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1400, height: 800))
            func line(_ t: String, _ y: CGFloat, _ size: CGFloat, _ w: UIFont.Weight) {
                (t as NSString).draw(at: CGPoint(x: 110, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: w), .foregroundColor: UIColor.black])
            }
            line("Priya Raman", 110, 76, .bold)
            line("Director of Sales", 210, 46, .regular)
            line("Northwind Analytics LLC", 280, 46, .medium)
            line("+1 (630) 555-0142", 450, 44, .regular)
            line("priya.raman@northwind-analytics.com", 520, 44, .regular)
            line("www.northwind-analytics.com", 590, 44, .regular)
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: img).creationDate = Date() }
            UserDefaults.standard.set(true, forKey: key)
        } catch {}
    }

    /// UI tests: a two-page letter photographed a few seconds apart (taken now), so a Test run makes one two-page PDF.
    static func seedPaper() async {
        let key = "uitest.seededPaper"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let pages: [[String]] = [
            ["RESIDENTIAL LEASE AGREEMENT", "", "This Lease Agreement is made on November 26, 2026 between", "Maple Grove Properties LLC (the Landlord) and",
             "Jordan Ellis (the Tenant) for the apartment at", "218 Cedar Lane, Unit 4B, Naperville, Illinois.", "",
             "1. Term. The lease begins on December 1, 2026 and ends on", "November 30, 2027.", "2. Rent. The monthly rent is $1,850, due on the first",
             "day of each month. A late fee of $75 applies after the fifth.", "3. Deposit. A security deposit of $1,850 is held by the Landlord.", "",
             "Page 1 of 2"],
            ["4. Utilities. The Tenant pays electricity and internet.", "The Landlord pays water, sewer and trash collection.",
             "5. Pets. One cat or small dog is allowed with written consent.", "6. Notice. Either party gives sixty days written notice",
             "before the end of the term.", "", "Signed by the Landlord and the Tenant on the date above.", "", "Page 2 of 2"]]
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        var images: [UIImage] = []
        for lines in pages {
            images.append(UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 1900), format: f).image { ctx in
                UIColor(red: 0.42, green: 0.36, blue: 0.30, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1400, height: 1900))   // a desk
                UIColor(white: 0.96, alpha: 1).setFill(); ctx.fill(CGRect(x: 120, y: 110, width: 1160, height: 1640))                     // the page
                for (i, t) in lines.enumerated() {
                    let head = i == 0
                    (t as NSString).draw(at: CGPoint(x: head ? 330 : 190, y: 200 + CGFloat(i) * 92),
                                         withAttributes: [.font: UIFont.systemFont(ofSize: head ? 50 : 36, weight: head ? .bold : .regular), .foregroundColor: UIColor(white: 0.1, alpha: 1)])
                }
            })
        }
        do {
            let now = Date()
            try await PHPhotoLibrary.shared().performChanges {
                for (i, img) in images.enumerated() { PHAssetChangeRequest.creationRequestForAsset(from: img).creationDate = now.addingTimeInterval(Double(i) * 20 - 60) }
            }
            UserDefaults.standard.set(true, forKey: key)
        } catch {}
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
                if k.weekly {
                    // Which day of the week: seven chips that wrap, never a sideways scroller.
                    HandyFlow(spacing: 6) {
                        ForEach(1...7, id: \.self) { w in
                            HChip(text: Calendar.current.shortWeekdaySymbols[w - 1], selected: (p.weekday ?? 1) == w) { var q = p; q.weekday = w; store.set(k, q) }
                                .accessibilityIdentifier("smartrun-weekday-\(w)")
                        }
                    }
                } else {
                    Picker(L("How often"), selection: Binding(get: { p.twice }, set: { var q = p; q.twice = $0; store.set(k, q) })) {
                        Text(L("Once a day")).tag(false); Text(L("Twice a day")).tag(true)
                    }.pickerStyle(.segmented)
                }
                DatePicker(L(p.twice ? "First time" : "Time"), selection: Binding(get: {
                    Calendar.current.date(from: DateComponents(hour: p.hour, minute: p.minute)) ?? Date()
                }, set: { d in var q = p; let c = Calendar.current.dateComponents([.hour, .minute], from: d); q.hour = c.hour ?? 20; q.minute = c.minute ?? 0; store.set(k, q) }),
                           displayedComponents: .hourAndMinute).font(HandyFont.body)
                Text((p.weekday.map { Calendar.current.weekdaySymbols[min(max($0, 1), 7) - 1] + " · " } ?? "")
                     + p.times.map { ChainSchedule.clock(hour: $0.hour, minute: $0.minute, uses24h: false) }.joined(separator: " " + L("and") + " "))
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
            if k == .voiceNotes {
                Button { pickingMemoFolder = true } label: {
                    Label(SmartVoice.folder.map { "\(L("Memos from")) \($0.lastPathComponent)" } ?? L("Choose the folder your memos go in…"), systemImage: "folder")
                }.textButton().accessibilityIdentifier("smartrun-memofolder")
                Text(L("In Voice Memos, tap ••• › Share › Save to Files and pick this folder. Any recorder app that saves to Files works too."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if k == .receipts {
                Button { pickingFolder = true } label: {
                    Label(SmartReceipts.folder.map { "\(L("PDFs from")) \($0.lastPathComponent)" } ?? L("Also read PDFs from a folder…"), systemImage: "folder")
                }.textButton().accessibilityIdentifier("smartrun-folder")
            }
            HStack(spacing: HandySpacing.s8) {
                Button { Task { await testRun(k) } } label: { Label(L("Test run"), systemImage: "play.circle").frame(maxWidth: .infinity) }
                    .secondaryButton().disabled(store.working != nil).accessibilityIdentifier("smartrun-test-\(k.rawValue)")
                if k == .contactsBackup, store.contacts != nil, store.waitingCount(k) == 0 {
                    // Nobody's gone: the latest copy is still worth seeing (and emailing to yourself).
                    NavigationLink(value: "smartcontacts") { Text(L("See the backup")).frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smartrun-check-\(k.rawValue)")
                }
                if store.waitingCount(k) > 0 {
                    NavigationLink(value: k == .tidyPhotos ? "smarttidy" : k == .overdueInvoices ? "smartinvoices" : k == .drives ? "smartdrives" : k == .heavyVideos ? "smartvideos" : k == .readyToPost ? "smartposts" : k == .dayCollage ? "smartcollage" : k == .businessCards ? "smartcards" : k == .paperPDFs ? "smartpapers" : k == .weekFilm ? "smartweek" : k == .contactsBackup ? "smartcontacts" : k == .voiceNotes ? "smartmemos" : "smartreceipts") {
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
        if on, k == .overdueInvoices {
            // Nothing to read on the phone: the invoices are Tenzy's own.
        } else if on, k == .voiceNotes {
            if SmartVoice.folder == nil { pickingMemoFolder = true }
            let asked = await withCheckedContinuation { c in Permission.speech { c.resume(returning: $0) } }
            guard asked == .authorized else {
                note = L("Tenzy needs Speech Recognition to write up memos — allow it in Settings › Apps › Tenzy. It runs on your phone."); return
            }
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if !granted { note = L("Notifications are off for Tenzy, so it can't tell you when this is ready. Turn them on in Settings › Tenzy › Notifications.") }
        } else if on, k == .contactsBackup {
            guard await ContactsEngine.requestAccess() else {
                note = L("Tenzy needs Contacts access to back them up — allow it in Settings › Apps › Tenzy › Contacts."); return
            }
        } else if on, k == .drives {
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
        if k == .overdueInvoices {
            let n = store.waitingCount(.overdueInvoices)
            note = n > 0 ? "\(L("Test run found")) \(n) \(L(n == 1 ? "overdue invoice" : "overdue invoices")). \(L("Tap Check to send the reminders."))"
                         : L("Test run worked: no invoices are overdue.")
            HandyHaptics.success(); return
        }
        if k == .drives {
            let n = store.waitingCount(.drives)
            note = n > 0 ? "\(L("Test run found")) \(n) \(L(n == 1 ? "drive" : "drives")). \(L("Tap Check to log the ones for work."))"
                         : (AutoPark.isOn ? L("Test run worked: no drives yet this week. Your next drive shows up here once you park.")
                                          : L("Switch this on first — it uses Find my car's drive detection."))
            HandyHaptics.success(); return
        }
        if k == .voiceNotes {
            guard SmartVoice.folder != nil else { pickingMemoFolder = true; note = L("First choose the folder your voice memos are saved in."); return }
            let before = store.waitingCount(k)
            await store.run(k, test: true)
            let found = store.waitingCount(k) - before
            note = found > 0 ? "\(L("Test run wrote up")) \(found) \(L(found == 1 ? "voice memo" : "voice memos")). \(L("Tap Check to read them."))"
                             : L("Test run worked: no new voice memos in that folder from the last 24 hours.")
            HandyHaptics.success(); return
        }
        if k == .contactsBackup {
            guard await ContactsEngine.requestAccess() else {
                note = L("Tenzy needs Contacts access to back them up — allow it in Settings › Apps › Tenzy › Contacts."); return
            }
            await store.run(k, test: true)
            if let r = store.contacts {
                note = "\(L("Test run backed up")) \(r.total) \(L(r.total == 1 ? "contact" : "contacts")) \(L("to Files › Tenzy › Contact Backups."))"
                    + (r.waiting.isEmpty ? "" : " \(r.waiting.count) \(L(r.waiting.count == 1 ? "is gone since the copy before — tap Check." : "are gone since the copy before — tap Check."))")
            } else { note = L("The backup couldn't be made — check that Tenzy can use Contacts.") }
            HandyHaptics.success(); return
        }
        guard await photosOK() else { return }
        let before = store.waitingCount(k)
        await store.run(k, test: true)
        let found = store.waitingCount(k) - before
        if k == .tidyPhotos {
            let bytes = store.tidy.reduce(Int64(0)) { $0 + $1.bytes }
            note = store.waitingCount(k) > 0 ? "\(L("Test run found")) \(store.waitingCount(k)) \(L("photos you won't miss")) · \(PhotoCleaner.format(bytes)). \(L("Tap Check — nothing goes until you say."))"
                                             : L("Test run worked: nothing to tidy — no old screenshots, duplicates or extra burst frames.")
        } else if k == .businessCards {
            note = found > 0 ? "\(L("Test run found")) \(found) \(L(found == 1 ? "business card" : "business cards")). \(L("Check them before they're saved."))"
                             : L("Test run worked: no business cards in your photos from the last 24 hours.")
        } else if k == .weekFilm {
            note = found > 0 ? L("Test run made this week's film from the last seven days. Tap Check to watch it.")
                             : L("Test run worked: the last seven days need at least five good moments — photos of people or clips — across two days.")
        } else if k == .paperPDFs {
            note = found > 0 ? "\(L("Test run made")) \(found) \(L(found == 1 ? "searchable PDF" : "searchable PDFs")). \(L("Tap Check to look through them."))"
                             : L("Test run worked: no photos of letters, bills or forms from the last 24 hours.")
                               + (Launch.uitest ? " [" + SmartPapers.trail.joined(separator: " | ") + "]" : "")
        } else if k == .dayCollage {
            note = found > 0 ? L("Test run made today's collage. Tap Check to see it.")
                             : L("Test run worked: fewer than three good photos of people from the last 24 hours, so no collage yet.")
        } else if k == .readyToPost {
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
            if entry.keep != nil {
                Toggle(isOn: Binding(get: { entry.keep == true }, set: { var e = entry; e.keep = $0; store.update(e) })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("Also keep it in Warranty")).font(HandyFont.caption.weight(.semibold))
                        Text(keepLine).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.tint(HandyColor.accent).accessibilityIdentifier("smartreceipt-keep")
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

    /// "Return by Dec 25 · 1-year warranty reminder", from what the small print said.
    private var keepLine: String {
        var parts: [String] = []
        if let d = entry.returnDays, let by = Calendar.current.date(byAdding: .day, value: d, to: entry.date ?? entry.taken) {
            parts.append("\(L("Return by")) \(by.formatted(date: .abbreviated, time: .omitted))")
        }
        if entry.warrantyMonths != nil { parts.append(L("a reminder before the 1-year warranty ends")) }
        return parts.isEmpty ? L("With its photo, to find it again") : parts.joined(separator: " · ")
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

/// What a tidy-up found, grouped, with what's kept and why. Pick the groups, then Delete — iPhone asks first.
struct SmartTidyReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var done: String?
    @State private var open: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Tidy up")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                if store.tidy.isEmpty && done == nil {
                    EmptyState(icon: "sparkles.rectangle.stack", line: "Nothing to tidy", sub: "Old screenshots, duplicates and extra burst frames show up here after a run.")
                }
                ForEach(store.tidy) { g in group(g) }
                let chosen = store.tidy.filter(\.selected)
                if !chosen.isEmpty {
                    let n = chosen.reduce(0) { $0 + $1.ids.count }, bytes = chosen.reduce(Int64(0)) { $0 + $1.bytes }
                    Button(role: .destructive) {
                        Task {
                            if let freed = await store.deleteTidy() {
                                done = "\(L("Deleted — frees")) \(PhotoCleaner.format(freed)) \(L("once Recently Deleted is emptied (or by itself in 30 days)."))"
                                HandyHaptics.success()
                            }
                        }
                    } label: { Text("\(L("Delete")) \(n) · \(L("frees")) \(PhotoCleaner.format(bytes))").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smarttidy-delete")
                    Text(L("iPhone asks before anything is deleted.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smarttidy")
    }

    private func group(_ g: SmartTidy.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { g.selected }, set: { on in
                if let i = store.tidy.firstIndex(where: { $0.id == g.id }) { store.tidy[i].selected = on; store.persistTidy() }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(L(SmartTidy.title(g))) · \(g.ids.count)").font(HandyFont.bodyStrong)
                    Text(PhotoCleaner.format(g.bytes)).font(HandyFont.caption.monospacedDigit()).foregroundStyle(HandyColor.accent)
                }
            }.tint(HandyColor.accent).accessibilityIdentifier("smarttidy-\(g.id)")
            Text(SmartTidy.why(g)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            // A look at what would go: a wrapping grid, the first 12 shown, the rest one tap away.
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: Array(g.ids.prefix(open == g.id ? 60 : 12)), options: nil)
            let list: [PHAsset] = (0..<assets.count).map { assets.object(at: $0) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(list, id: \.localIdentifier) { a in
                    PhotoThumb(asset: a).aspectRatio(1, contentMode: .fill).clipShape(RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
                }
            }
            if g.ids.count > 12 {
                Button { open = open == g.id ? nil : g.id } label: { Text(open == g.id ? L("Show fewer") : "\(L("Show more")) (\(g.ids.count - 12))") }.textButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smarttidy-group")
    }
}

/// Overdue invoices: how late each is, a reminder email ready (invoice attached, the right tone), Mark paid.
struct SmartInvoicesReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @ObservedObject private var invoices = InvoiceStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mail: Invoice.Doc?
    @State private var note: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Overdue invoices")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.accent).fixedSize(horizontal: false, vertical: true) }
                let list = store.overdue
                if list.isEmpty {
                    EmptyState(icon: "checkmark.seal", line: "Nothing overdue", sub: "Invoices show up here the day after their pay-by date.")
                }
                ForEach(list) { d in row(d) }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartinvoices")
        .sheet(item: $mail) { d in
            let m = SmartInvoices.reminder(d)
            MailDraft(to: SmartInvoices.email(d.to) ?? "", subject: m.subject, body: m.body,
                      attachment: (Invoice.pdf(d), "\(d.number).pdf", "application/pdf")).ignoresSafeArea()
        }
    }

    private func row(_ d: Invoice.Doc) -> some View {
        let late = SmartInvoices.daysLate(d)
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = d.currency
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(d.who.isEmpty ? d.number : d.who).font(HandyFont.cardTitle)
                Spacer()
                Text(f.string(from: NSNumber(value: d.total)) ?? "").font(HandyFont.cardTitle.monospacedDigit())
            }
            Text("\(d.number) · \(late) \(L(late == 1 ? "day late" : "days late"))")
                .font(HandyFont.caption).foregroundStyle(late > 30 ? HandyColor.danger : HandyColor.amber)
            let tone = SmartInvoices.tone(daysLate: late)
            Text(L(tone == .friendly ? "A friendly reminder is ready." : tone == .firm ? "A firm reminder is ready." : "A final notice is ready."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                if MailDraft.canSend {
                    Button { mail = d } label: { Label(L("Send the reminder"), systemImage: "paperplane").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smartinvoice-send")
                } else {
                    ShareLink(item: SmartInvoices.reminder(d).body) { Label(L("Share the reminder"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                        .primaryButton()
                }
                Button { invoices.setPaid(d.id, true); note = "\(d.number) \(L("marked paid."))"; store.objectWillChange.send() } label: {
                    Label(L("Mark paid"), systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                }.secondaryButton().accessibilityIdentifier("smartinvoice-paid")
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartinvoice-card")
    }
}

/// The business cards a run read: each as the contact it will become. Anyone already in Contacts is shown, not
/// added again. Save adds the new ones; each has a ready "nice to meet you" email.
struct SmartCardsReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var done: String?
    @State private var mail: SmartCards.Entry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Today's business cards")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                if store.cards.isEmpty && done == nil {
                    EmptyState(icon: "person.text.rectangle", line: "Nothing waiting", sub: "Business cards show up here after the next run.")
                }
                ForEach(store.cards) { e in card(e) }
                let new = store.cards.filter { $0.already == nil }.count
                if !store.cards.isEmpty {
                    Button {
                        Task {
                            if let n = await store.saveCards() {
                                done = n == 0 ? L("Everyone was already in your Contacts.") : "\(n) \(L(n == 1 ? "contact saved, with the day you met." : "contacts saved, with the day you met."))"
                                HandyHaptics.success()
                            } else { done = L("Tenzy needs Contacts access to save them — allow it in Settings.") }
                        }
                    } label: { Text(new == 0 ? L("Done — all already saved") : "\(L("Save")) \(new) \(L(new == 1 ? "new contact" : "new contacts"))").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smartcards-save")
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartcards")
        .sheet(item: $mail) { e in
            let m = SmartCards.niceToMeetYou(e, on: e.taken)
            MailDraft(to: e.emails.first ?? "", subject: m.subject, body: m.body).ignoresSafeArea()
        }
    }

    private func card(_ e: SmartCards.Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(L("Name"), text: Binding(get: { e.name }, set: { var x = e; x.name = $0; store.updateCard(x) }))
                    .font(HandyFont.cardTitle).accessibilityIdentifier("smartcard-name")
                Button(role: .destructive) { store.dropCard(e.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }
                    .accessibilityLabel(L("Leave this one out"))
            }
            let line = [e.title, e.company].filter { !$0.isEmpty }.joined(separator: " · ")
            if !line.isEmpty { Text(line).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            ForEach(e.phones, id: \.self) { Label($0, systemImage: "phone").font(HandyFont.caption) }
            ForEach(e.emails, id: \.self) { Label($0, systemImage: "envelope").font(HandyFont.caption) }
            if !e.website.isEmpty { Label(e.website, systemImage: "globe").font(HandyFont.caption) }
            if let a = e.already {
                Label("\(L("Already in Contacts as")) \(a)", systemImage: "person.crop.circle.badge.checkmark").font(HandyFont.caption).foregroundStyle(HandyColor.accent)
            }
            if !e.emails.isEmpty, MailDraft.canSend {
                Button { mail = e } label: { Label(L("Write a nice-to-meet-you email"), systemImage: "envelope.open") }.textButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartcard-card")
    }
}

/// Apple's mail sheet with the address, subject and words filled in; the person edits and sends.
struct MailDraft: UIViewControllerRepresentable {
    static var canSend: Bool { MFMailComposeViewController.canSendMail() }
    let to: String, subject: String, body: String
    var attachment: (data: Data, name: String, mime: String)? = nil
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coord { Coord(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if !to.isEmpty { vc.setToRecipients([to]) }
        vc.setSubject(subject); vc.setMessageBody(body, isHTML: false)
        if let a = attachment { vc.addAttachmentData(a.data, mimeType: a.mime, fileName: a.name) }
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    final class Coord: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func mailComposeController(_ c: MFMailComposeViewController, didFinishWith r: MFMailComposeResult, error: Error?) { dismiss() }
    }
}

/// The day's collage: see it full size, try another layout, save it to Photos or send it.
struct SmartCollageReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Today's collage")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                if let r = store.collages.first {
                    let url = SmartCollage.folder.appendingPathComponent(r.file)
                    if let img = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: img).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).contentShape(Rectangle())
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                            .accessibilityLabel("\(L("Collage of")) \(r.count) \(L("photos"))")
                            .accessibilityValue(Text(verbatim: Launch.uitest ? "\(Int(img.size.width))x\(Int(img.size.height)) \(r.count)" : ""))
                            .accessibilityIdentifier("smartcollage-image")
                    }
                    Text("\(r.count) \(L("photos — one per moment, sharpest first, faces kept in frame."))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Text(L("Layout")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    HandyFlow(spacing: 6) {
                        ForEach([CollageLayout.hero, .grid, .mosaic, .sideHero], id: \.self) { l in
                            HChip(text: L(l.title), selected: r.layout == l.rawValue) {
                                busy = true
                                Task { await store.remakeCollage(r.id, layout: l); busy = false }
                            }.disabled(busy)
                        }
                    }
                    if busy { HStack { BusySpinner(); Text(L("Arranging the photos…")).font(HandyFont.caption) } }
                    HStack(spacing: HandySpacing.s8) {
                        Button {
                            Task { saved = await store.saveCollage(r.id); HandyHaptics.success() }
                        } label: { Label(L(r.saved || saved ? "Saved to Photos" : "Save to Photos"), systemImage: r.saved || saved ? "checkmark.circle.fill" : "square.and.arrow.down").frame(maxWidth: .infinity) }
                            .primaryButton().disabled(r.saved || saved || busy).accessibilityIdentifier("smartcollage-save")
                        ShareLink(item: url) { Label(L("Send"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                } else {
                    EmptyState(icon: "square.grid.3x3.fill", line: "Nothing waiting", sub: "Today's collage shows up here after the next run.")
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartcollage")
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
                .accessibilityValue(Text(verbatim: Launch.uitest ? (r.size.map { "\($0[0])x\($0[1])" } ?? "unknown") : ""))
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

/// Today's paper, made into PDFs: each document with its first page, its name (from what it says — change it if you
/// like), how many pages and searchable words; look through every page before saving it where you want.
struct SmartPapersReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var looking: SmartPapers.Entry?
    @State private var exporting: [URL] = []
    @State private var exportIDs: [String] = []
    @State private var busy: String?
    @State private var done: String?

    private var waiting: [SmartPapers.Entry] { store.papers.filter { !$0.saved && !$0.file.isEmpty } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Today's paper, as PDFs")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                Text(L("Each page was found in the photo, flattened and cleaned, and its words can be searched, selected and copied."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                if waiting.isEmpty && done == nil {
                    EmptyState(icon: "doc.viewfinder", line: "Nothing waiting", sub: "Photos of letters, bills and forms show up here as PDFs after the next run.")
                }
                ForEach(Array(waiting.enumerated()), id: \.element.id) { i, e in card(e, next: i + 1 < waiting.count ? waiting[i + 1] : nil) }
                if waiting.count > 1 {
                    Button { saveAll() } label: { Label("\(L("Save all to Files")) (\(waiting.count))", systemImage: "folder").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("smartpapers-saveall")
                }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartpapers")
        .sheet(item: $looking) { e in PaperLook(entry: e) }
        .sheet(isPresented: Binding(get: { !exporting.isEmpty }, set: { if !$0 { exporting = [] } })) {
            FilesExporter(urls: exporting) { ok in
                if ok {
                    for id in exportIDs { store.markPaperSaved(id) }
                    done = exportIDs.count == 1 ? L("Saved to Files.") : "\(exportIDs.count) \(L("PDFs saved to Files."))"
                    HandyHaptics.success()
                }
                exporting = []; exportIDs = []
            }.ignoresSafeArea()
        }
    }

    private func saveAll() {
        let list = waiting
        exporting = list.compactMap(SmartPapers.named); exportIDs = list.map(\.id)
    }

    private func card(_ e: SmartPapers.Entry, next: SmartPapers.Entry?) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                Button { looking = e } label: {
                    PaperThumb(file: e.file).frame(width: 92, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain).accessibilityLabel(L("Look through every page"))
                VStack(alignment: .leading, spacing: 4) {
                    TextField(L("Name"), text: Binding(get: { e.title }, set: { store.renamePaper(e.id, $0) }))
                        .font(HandyFont.cardTitle).accessibilityIdentifier("smartpaper-title")
                    Text(verbatim: "\(e.pages.count) \(L(e.pages.count == 1 ? "page" : "pages")) · \(e.words) \(L("words you can search"))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).accessibilityIdentifier("smartpaper-facts")
                    Text(e.fileName).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Button(role: .destructive) { store.dropPaper(e.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(HandyColor.textSecondary) }
                    .frame(width: 44, height: 44).accessibilityLabel(L("Leave this one out"))
            }
            HStack(spacing: HandySpacing.s8) {
                Button { looking = e } label: { Label(L("Look through"), systemImage: "doc.text.magnifyingglass").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("smartpaper-look")
                Button { if let u = SmartPapers.named(e) { exporting = [u]; exportIDs = [e.id] } } label: {
                    Label(L("Save to Files"), systemImage: "folder").frame(maxWidth: .infinity)
                }.primaryButton().accessibilityIdentifier("smartpaper-save")
            }
            HStack(spacing: HandySpacing.s16) {
                if let u = SmartPapers.named(e) {
                    ShareLink(item: u) { Label(L("Share"), systemImage: "square.and.arrow.up") }.font(HandyFont.caption)
                }
                if let n = next {
                    Button { Task { busy = e.id; _ = await store.joinPaper(e.id, with: n.id); busy = nil } } label: {
                        Label(L("Join with the next one"), systemImage: "arrow.down.doc")
                    }.font(HandyFont.caption).accessibilityIdentifier("smartpaper-join")
                }
                if e.pages.count > 1 {
                    Button { Task { busy = e.id; _ = await store.splitPaper(e.id); busy = nil } } label: {
                        Label(L("One PDF per page"), systemImage: "rectangle.split.1x2")
                    }.font(HandyFont.caption).accessibilityIdentifier("smartpaper-split")
                }
                if busy == e.id { ProgressView() }
            }
            .disabled(busy != nil)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartpaper-card")
    }
}

/// The first page of a made PDF, drawn small.
private struct PaperThumb: View {
    let file: String
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            HandyColor.surface
            if let img { Image(uiImage: img).resizable().scaledToFill() }
        }
        .clipped()
        .contentShape(Rectangle())
        .task(id: file) {
            let url = SmartPapers.folder.appendingPathComponent(file)
            img = await Task.detached(priority: .userInitiated) {
                PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 276, height: 360), for: .mediaBox)
            }.value
        }
    }
}

/// Every page of a made PDF, full size, before it's saved — with its words selectable.
private struct PaperLook: View {
    let entry: SmartPapers.Entry
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let d = try? Data(contentsOf: SmartPapers.folder.appendingPathComponent(entry.file)) { PDFPreview(data: d) }
                else { EmptyState(icon: "doc", line: "This PDF is gone", sub: "Run the autorun again to make it.") }
            }
            .navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() }.accessibilityIdentifier("paperlook-done") } }
        }
        .accessibilityIdentifier("paperlook")
    }
}

/// The week's film: watch it in place, lay one of your songs under it, keep it in Photos.
struct SmartWeekReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var songs: [MusicTrack.Song] = []
    @State private var busy: String?
    @State private var note: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Your week's film")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                Text(L("The best moments of the week, day by day — the whole of every photo, the liveliest seconds of your clips."))
                    .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let note { Text(note).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
                if store.films.isEmpty {
                    EmptyState(icon: "film.stack", line: "Nothing waiting", sub: "Your week's film shows up here after its next run.")
                }
                ForEach(store.films) { f in card(f) }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartweek")
        .task { songs = await MusicTrack.filesInTenzy() }
    }

    private func card(_ f: SmartWeek.Result) -> some View {
        let url = SmartWeek.folder.appendingPathComponent(f.file)
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(f.title).font(HandyFont.cardTitle)
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(9.0 / 16.0, contentMode: .fit).frame(maxHeight: 460).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).contentShape(Rectangle())
                .accessibilityIdentifier("smartweek-player")
            Text(verbatim: "\(SocialPost.clock(f.seconds)) · \(f.photos) \(L(f.photos == 1 ? "photo" : "photos")) · \(f.clips) \(L(f.clips == 1 ? "clip" : "clips")) · \(f.days) \(L(f.days == 1 ? "day" : "days"))")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).accessibilityIdentifier("smartweek-facts")
            if let s = f.song { Label("\(L("Music")): \(s)", systemImage: "music.note").font(HandyFont.caption) }
            if !songs.isEmpty {
                Text(L("Add music from your songs")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HandyFlow(spacing: 6) {
                    ForEach(songs.prefix(8)) { song in
                        HChip(text: song.title, selected: f.song == song.title) {
                            busy = f.id
                            Task { if !(await store.addMusic(f.id, song: song)) { note = L("That song couldn't be added — try another one.") }; busy = nil }
                        }
                    }
                }
            }
            if f.saved {
                Label(L("Saved to Photos"), systemImage: "checkmark.circle.fill").font(HandyFont.caption).foregroundStyle(HandyColor.success)
                    .accessibilityIdentifier("smartweek-saved")
            } else {
                Button {
                    busy = f.id
                    Task {
                        if await store.saveFilm(f.id) { HandyHaptics.success() } else { note = L("Tenzy isn't allowed to add to Photos. Turn it on in Settings › Apps › Tenzy › Photos.") }
                        busy = nil
                    }
                } label: {
                    Label(busy == f.id ? L("Saving…") : L("Save to Photos"), systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }.primaryButton().disabled(busy != nil).accessibilityIdentifier("smartweek-save")
            }
            ShareLink(item: url) { Label(L("Share"), systemImage: "square.and.arrow.up") }.font(HandyFont.caption)
            if busy == f.id { ProgressView() }
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartweek-card")
    }
}

/// The latest contacts copy: where it is, who's new, and — the reason it exists — who's gone since the copy before,
/// each one tap from coming back.
struct SmartContactsReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mail = false
    @State private var done: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Your contacts, backed up")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                if let done { Label(done, systemImage: "checkmark.seal.fill").font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).fixedSize(horizontal: false, vertical: true) }
                if let r = store.contacts { report(r) }
                else { EmptyState(icon: "person.crop.circle.badge.checkmark", line: "No backup yet", sub: "Tap Test run on the autoruns page to make the first copy.") }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartcontacts")
        .sheet(isPresented: $mail) {
            if let r = store.contacts, let d = try? Data(contentsOf: SmartContacts.folder.appendingPathComponent(r.file)) {
                MailDraft(to: "", subject: L("My contacts backup"), body: L("A copy of my contacts, to keep safe. Open the attachment on any phone or computer to bring them back."),
                          attachment: (d, r.file, "text/vcard")).ignoresSafeArea()
            }
        }
    }

    @ViewBuilder private func report(_ r: SmartContacts.Report) -> some View {
        let url = SmartContacts.folder.appendingPathComponent(r.file)
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("\(r.total) \(L(r.total == 1 ? "contact" : "contacts")) · \(r.at.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.shield.fill")
                .font(HandyFont.bodyStrong).foregroundStyle(HandyColor.success).accessibilityIdentifier("smartcontacts-total")
            Text(L("Saved in Files › On My iPhone › Tenzy › Contact Backups, and in iCloud Drive when it's on. The last eight copies are kept."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: HandySpacing.s8) {
                if MailDraft.canSend {
                    Button { mail = true } label: { Label(L("Email it to myself"), systemImage: "envelope").frame(maxWidth: .infinity) }.secondaryButton()
                }
                ShareLink(item: url) { Label(L("Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.secondaryButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        let waiting = r.waiting
        if !waiting.isEmpty {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text("\(waiting.count) \(L(waiting.count == 1 ? "contact is gone since the copy before" : "contacts are gone since the copy before"))")
                    .font(HandyFont.cardTitle).accessibilityIdentifier("smartcontacts-gone")
                Text(L("Deleted by mistake, or lost with an account? Bring them back exactly as they were."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                ForEach(waiting, id: \.self) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(HandyFont.bodyStrong)
                            if let line = p.emails.first ?? p.phones.first { Text(line).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                        }
                        Spacer()
                        Button(L("Bring back")) {
                            let n = store.restoreContacts([p])
                            done = n == 1 ? "\(p.name) \(L("is back in Contacts."))" : L("Contacts wouldn't take it back — check that Tenzy can use Contacts.")
                            if n == 1 { HandyHaptics.success() }
                        }.secondaryButton().accessibilityIdentifier("smartcontacts-restore")
                    }
                }
                HStack(spacing: HandySpacing.s8) {
                    if waiting.count > 1 {
                        Button {
                            let n = store.restoreContacts(waiting)
                            done = "\(n) \(L(n == 1 ? "contact is back in Contacts." : "contacts are back in Contacts."))"; HandyHaptics.success()
                        } label: { Text(L("Bring them all back")).frame(maxWidth: .infinity) }.primaryButton()
                    }
                    Button { store.keepContactsGone() } label: { Text(L("They were meant to go")).frame(maxWidth: .infinity) }.secondaryButton()
                }
            }
            .cardStyle(padding: HandySpacing.s12)
        }
        if !r.added.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(r.added.count) \(L(r.added.count == 1 ? "new since the copy before" : "new since the copy before"))").font(HandyFont.cardTitle)
                Text(r.added.prefix(12).joined(separator: ", ") + (r.added.count > 12 ? " …" : ""))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .cardStyle(padding: HandySpacing.s12)
        }
    }
}

/// Today's voice memos, written up: headline, key points, decisions and to-dos — the transcript one tap away.
struct SmartMemosReview: View {
    @ObservedObject private var store = SmartRunStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [String: String] = [:]
    @State private var mail: SmartVoice.Entry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                HStack {
                    Button { dismiss() } label: { Label(L("Back"), systemImage: "chevron.left").font(HandyFont.bodyStrong) }.accessibilityIdentifier("page-back")
                    Spacer()
                }
                Text(L("Your voice memos, written up")).font(HandyFont.display).accessibilityAddTraits(.isHeader)
                Text(L("Heard on your phone — nothing was sent anywhere."))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                let shown = store.memos.filter { !$0.done }
                if shown.isEmpty {
                    EmptyState(icon: "waveform.and.mic", line: "Nothing waiting", sub: "Memos saved to your folder show up here, written up, after the next run.")
                }
                ForEach(shown) { e in card(e) }
            }
            .padding(HandySpacing.gutter)
        }
        .background(TenzyBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("smartmemos")
        .sheet(item: $mail) { e in
            MailDraft(to: "", subject: e.headline, body: e.text).ignoresSafeArea()
        }
    }

    private func card(_ e: SmartVoice.Entry) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(e.headline).font(HandyFont.cardTitle).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("smartmemo-headline")
            Text("\(e.recorded.formatted(date: .abbreviated, time: .shortened)) · \(MeetingNotes.clock(e.seconds))\(e.byAI ? " · " + L("written by Apple Intelligence") : "")")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if !e.points.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(e.points, id: \.self) { Text("• " + $0).font(HandyFont.body).fixedSize(horizontal: false, vertical: true) }
                }
            }
            if !e.decisions.isEmpty {
                Text(L("Decided")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(e.decisions, id: \.self) { Text("• " + $0).font(HandyFont.body).fixedSize(horizontal: false, vertical: true) }
            }
            if !e.todos.isEmpty {
                Text(L("To-dos")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(e.todoLines, id: \.self) { Text("☐ " + $0).font(HandyFont.body).fixedSize(horizontal: false, vertical: true) }
                Button {
                    Task {
                        let n = await SmartVoice.toReminders(e)
                        notes[e.id] = n < 0 ? L("Allow Reminders for Tenzy in Settings, then tap again.") : "\(n) \(L(n == 1 ? "to-do added to Reminders." : "to-dos added to Reminders."))"
                        if n > 0 { HandyHaptics.success() }
                    }
                } label: { Label(L("Put the to-dos in Reminders"), systemImage: "checklist").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("smartmemo-reminders")
            }
            if let n = notes[e.id] { Text(n).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            DisclosureGroup(L("The whole transcript")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(e.transcript, id: \.self) { Text($0).font(HandyFont.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                }.padding(.top, 6)
            }.font(HandyFont.caption)
            HStack(spacing: HandySpacing.s16) {
                ShareLink(item: e.text + "\n" + e.transcript.joined(separator: "\n\n")) { Label(L("Share"), systemImage: "square.and.arrow.up") }
                if MailDraft.canSend { Button { mail = e } label: { Label(L("Email the notes"), systemImage: "envelope") } }
                Spacer()
                Button { store.memoDone(e.id) } label: { Label(L("Done"), systemImage: "checkmark") }.accessibilityIdentifier("smartmemo-done")
            }.font(HandyFont.caption)
        }
        .cardStyle(padding: HandySpacing.s12)
        .accessibilityElement(children: .contain).accessibilityIdentifier("smartmemo-card")
    }
}

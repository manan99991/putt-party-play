import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Read Aloud — any text, PDF, photo of a page, or web article, spoken in a natural voice with the
/// current sentence highlighted. Skip, speed up, pick a voice, keep listening with the screen off,
/// or export the whole thing as an audio file. For dyslexia, tired eyes, and the commute.
struct ReadAloudView: View {
    @StateObject private var reader = Reader()
    @State private var text = ""
    @State private var urlText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var busy = false
    @State private var errorText: String?
    @State private var exported: URL?
    @State private var voicePick = false
    @AppStorage("readaloud.rate") private var rate = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("readaloud.voice") private var voiceID = ""

    var body: some View {
        ToolPage(title: "Read Aloud", subtitle: "Paste, open a PDF, snap a page, or drop in a link — then listen, with the sentence highlighted.") {
            if reader.sentences.isEmpty {
                VStack(spacing: HandySpacing.s8) {
                    TextEditor(text: $text).frame(minHeight: 120).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                        .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                        .overlay(alignment: .topLeading) { if text.isEmpty { Text("Paste text here…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) } }
                    HStack(spacing: HandySpacing.s8) {
                        Button("Paste") { if let s = UIPasteboard.general.string { text = s } }.compactButton()
                        Button { load(text) } label: { Label("Read this", systemImage: "play.fill") }.primaryButton().disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                HStack(spacing: HandySpacing.s8) {
                    TextField("https://… article link", text: $urlText).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(HandySpacing.s12).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                        .onSubmit { loadWeb() }
                    Button { loadWeb() } label: { Image(systemName: "arrow.down.doc").frame(width: 36, height: 36) }.compactButton().disabled(URL(string: urlText)?.host == nil)
                }
                HStack(spacing: HandySpacing.s8) {
                    Button { showFiles = true } label: { Label("PDF", systemImage: "doc.fill").frame(maxWidth: .infinity) }.secondaryButton()
                    PhotosPicker(selection: $photoItem, matching: .images) { Label("Photo of a page", systemImage: "camera.viewfinder").frame(maxWidth: .infinity) }.secondaryButton()
                }
                if busy { HStack { ProgressView(); Text("Getting the text…").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) } }
            } else {
                player
            }
            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { busy = true; Task.detached { let t = ReadSource.fromPDF(url); await MainActor.run { busy = false; load(t) } } }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            busy = true
            Task { if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { let t = await AIEngine.recognizeText(img); await MainActor.run { busy = false; load(t) } } else { await MainActor.run { busy = false } } }
        }
        .onAppear { reader.rate = Float(rate); reader.voiceID = voiceID.isEmpty ? nil : voiceID; if Launch.sample, text.isEmpty { text = "Rooftop panels now supply a tenth of daytime demand in some cities. Utilities are responding with time-of-use pricing. The share is rising every year." } }
        .onDisappear { reader.pause() }
        .sheet(isPresented: $voicePick) { VoicePicker(language: NLLanguageGuess.language(of: reader.sentences.prefix(5).joined(separator: " ")), selected: $voiceID).onDisappear { reader.voiceID = voiceID.isEmpty ? nil : voiceID } }
    }

    private var player: some View {
        VStack(spacing: HandySpacing.s12) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(reader.sentences.enumerated()), id: \.offset) { i, s in
                            Text(s).font(.system(size: 19)).foregroundStyle(i == reader.index ? HandyColor.textPrimary : HandyColor.textSecondary)
                                .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                                .background(i == reader.index ? HandyColor.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .id(i).onTapGesture { reader.play(from: i) }
                        }
                    }.padding(HandySpacing.s8)
                }
                .frame(height: 320)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .onChange(of: reader.index) { _, i in withAnimation { proxy.scrollTo(i, anchor: .center) } }
            }
            ProgressView(value: reader.progress).tint(HandyColor.accent)
            HStack { Text("\(reader.index + 1) / \(reader.sentences.count)").font(HandyFont.caption).monospacedDigit(); Spacer(); Text("~\(reader.remainingMinutes) min left").font(HandyFont.caption) }.foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s16) {
                Button { reader.previous() } label: { Image(systemName: "backward.fill").font(.system(size: 22)) }.buttonStyle(.plain).accessibilityLabel("Previous sentence")
                Button { reader.playing ? reader.pause() : reader.play() } label: {
                    Image(systemName: reader.playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64)).foregroundStyle(HandyColor.accent)
                }.buttonStyle(.plain).accessibilityLabel(reader.playing ? "Pause" : "Play")
                Button { reader.next() } label: { Image(systemName: "forward.fill").font(.system(size: 22)) }.buttonStyle(.plain).accessibilityLabel("Next sentence")
            }.foregroundStyle(HandyColor.textPrimary).frame(maxWidth: .infinity)
            HStack { Image(systemName: "tortoise"); Slider(value: $rate, in: 0.3...0.7).tint(HandyColor.accent).onChange(of: rate) { _, r in reader.rate = Float(r) }; Image(systemName: "hare"); Text(String(format: "%.1f×", rate / Double(AVSpeechUtteranceDefaultSpeechRate))).font(HandyFont.caption).monospacedDigit().frame(width: 40) }.foregroundStyle(HandyColor.textSecondary)
            HStack(spacing: HandySpacing.s8) {
                Button { voicePick = true } label: { Label("Voice", systemImage: "person.wave.2") }.compactButton()
                Button { export() } label: { HStack { if reader.exporting { ProgressView() }; Label("Save as audio", systemImage: "waveform.badge.plus") } }.compactButton().disabled(reader.exporting)
                if let exported { ShareLink(item: exported) { Label("Share audio", systemImage: "square.and.arrow.up") }.compactButton() }
                Spacer()
                Button { reader.stop(); reader.sentences = []; exported = nil } label: { Image(systemName: "xmark").frame(width: 36, height: 36) }.compactButton()
            }
            Text("Keeps reading with the screen locked. Download Enhanced or Premium voices in Settings › Accessibility › Spoken Content for the most natural sound.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
    }

    private func load(_ t: String) {
        let clean = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { errorText = "Couldn't find any text to read."; return }
        errorText = nil; exported = nil
        reader.load(clean); reader.play()
    }

    private func loadWeb() {
        var s = urlText.trimmingCharacters(in: .whitespaces)
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard let u = URL(string: s) else { return }
        busy = true; errorText = nil
        Task { let t = await ReadSource.fromWeb(u); await MainActor.run { busy = false; if t.count < 80 { errorText = "That page didn't give up readable text (it may need a login or be built from scripts). Try pasting the article instead." } else { load(t) } } }
    }

    private func export() {
        Task { @MainActor in
            if let url = await reader.exportAudio() { exported = url; HandyHaptics.success() } else { errorText = "Couldn't render the audio." }
        }
    }
}

struct VoicePicker: View {
    let language: String?
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var all = false
    var body: some View {
        NavigationStack {
            List {
                Toggle("Show every language", isOn: $all)
                Button { selected = ""; dismiss() } label: { HStack { Text("Automatic (match the text)"); Spacer(); if selected.isEmpty { Image(systemName: "checkmark").foregroundStyle(HandyColor.accent) } } }.foregroundStyle(HandyColor.textPrimary)
                ForEach(Reader.voices(for: all ? nil : language ?? "en"), id: \.identifier) { v in
                    Button { selected = v.identifier; dismiss() } label: {
                        HStack {
                            VStack(alignment: .leading) { Text(v.name); Text("\(Locale.current.localizedString(forIdentifier: v.language) ?? v.language) · \(v.quality == .premium ? "Premium" : v.quality == .enhanced ? "Enhanced" : "Standard")").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                            Spacer(); if v.identifier == selected { Image(systemName: "checkmark").foregroundStyle(HandyColor.accent) }
                        }
                    }.foregroundStyle(HandyColor.textPrimary)
                }
            }
            .navigationTitle("Voice").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}

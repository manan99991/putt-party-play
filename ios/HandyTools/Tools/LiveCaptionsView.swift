import SwiftUI

/// Live Captions — real-time captions of the room, in big text, for as long as you need, in any of
/// the languages the phone can recognise on-device. Type a reply and the phone speaks it. Save the
/// transcript. Built for deaf and hard-of-hearing conversations, lectures and noisy calls.
struct LiveCaptionsView: View {
    @StateObject private var speech = SpeechStream()
    @StateObject private var speaker = Speaker()
    @AppStorage("captions.size") private var fontSize = 28.0
    @State private var reply = ""
    @State private var showLanguages = false

    var body: some View {
        ToolPage(title: "Live Captions", subtitle: "Real-time captions of what's being said — private, on-device, as long as you need.") {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: HandySpacing.s8) {
                        ForEach(Array(speech.committed.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(size: fontSize, weight: .medium)).foregroundStyle(HandyColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !speech.live.isEmpty { Text(speech.live).font(.system(size: fontSize, weight: .medium)).foregroundStyle(HandyColor.accent).frame(maxWidth: .infinity, alignment: .leading) }
                        if speech.committed.isEmpty && speech.live.isEmpty {
                            Text(speech.running ? "Listening…" : "Tap Start and captions appear here.").font(.system(size: fontSize * 0.8)).foregroundStyle(HandyColor.textSecondary)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }.padding(HandySpacing.s12)
                }
                .frame(height: 330)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(speech.running ? HandyColor.accent : HandyColor.border, lineWidth: speech.running ? 2 : 1))
                .onChange(of: speech.live) { _, _ in withAnimation { proxy.scrollTo("end") } }
                .onChange(of: speech.committed.count) { _, _ in withAnimation { proxy.scrollTo("end") } }
            }

            HStack(spacing: HandySpacing.s8) {
                Button { speech.running ? speech.stop() : speech.start() } label: {
                    Label(speech.running ? "Stop" : "Start captions", systemImage: speech.running ? "stop.fill" : "captions.bubble.fill").frame(maxWidth: .infinity)
                }.primaryButton()
                Button { showLanguages = true } label: { Text(speech.locale.localizedString(forLanguageCode: speech.locale.language.languageCode?.identifier ?? "en") ?? "Language").lineLimit(1) }.compactButton()
                Menu {
                    Button { fontSize = 22 } label: { Text("Normal") }; Button { fontSize = 28 } label: { Text("Large") }; Button { fontSize = 38 } label: { Text("Huge") }
                } label: { Image(systemName: "textformat.size").frame(width: 36, height: 36) }.compactButton().accessibilityLabel("Text size")
            }

            HStack(spacing: HandySpacing.s8) {
                TextField("Type a reply — the phone will say it", text: $reply)
                    .padding(HandySpacing.s12)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .submitLabel(.send).onSubmit { say() }
                Button { say() } label: { Image(systemName: "speaker.wave.2.fill").frame(width: 36, height: 36) }.compactButton().disabled(reply.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityLabel("Speak reply")
            }

            HStack(spacing: HandySpacing.s8) {
                Button { UIPasteboard.general.string = speech.transcript; HandyHaptics.success() } label: { Label("Copy", systemImage: "doc.on.doc") }.compactButton().disabled(speech.transcript.isEmpty)
                ShareLink(item: speech.transcript) { Label("Save transcript", systemImage: "square.and.arrow.up") }.compactButton().disabled(speech.transcript.isEmpty)
                Button(role: .destructive) { speech.clear() } label: { Label("Clear", systemImage: "trash") }.compactButton().disabled(speech.transcript.isEmpty)
                Spacer()
            }
            if let e = speech.errorText { LimitNote(e) }
            Text(speech.onDevice ? "Recognised on your phone — nothing is uploaded. Works offline." : "This language isn't available on-device on this phone, so Apple's servers handle the audio.")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onDisappear { speech.stop(); speaker.stop() }
        .sheet(isPresented: $showLanguages) { LanguagePicker(selected: $speech.locale) }
    }

    private func say() {
        let t = reply.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        speaker.say(t); reply = ""
    }
}

/// Picks a recognition language from what the phone supports.
struct LanguagePicker: View {
    @Binding var selected: Locale
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                ForEach(SpeechStream.supportedLocales.filter { query.isEmpty || (name($0)).localizedCaseInsensitiveContains(query) }, id: \.identifier) { l in
                    Button { selected = l; dismiss() } label: {
                        HStack { Text(name(l)); Spacer(); if l.identifier == selected.identifier { Image(systemName: "checkmark").foregroundStyle(HandyColor.accent) } }
                    }.foregroundStyle(HandyColor.textPrimary)
                }
            }
            .searchable(text: $query)
            .navigationTitle("Language").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func name(_ l: Locale) -> String { Locale.current.localizedString(forIdentifier: l.identifier) ?? l.identifier }
}

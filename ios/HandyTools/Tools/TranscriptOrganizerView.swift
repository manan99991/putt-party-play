import SwiftUI

/// The tidy, readable version of a transcript: fillers and stutters gone, sentences restored, short
/// paragraphs at topic changes — and a speaker chip on every paragraph. A phone can't tell voices apart
/// from live dictation, so tagging is honest: tap a paragraph's chip to say who said it, rename speakers
/// once, and every tag updates. Copy or share the organized text with names. Used by Voice → Notes.
struct TranscriptOrganizerView: View {
    let text: String
    @State private var paragraphs: [String] = []
    @State private var speakerOf: [Int: Int] = [:]
    @State private var speakers: [String] = ["Me", "Speaker 2"]
    @State private var renaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text(L("Organized")).font(HandyFont.bodyStrong)
                Spacer()
                Button { renaming.toggle() } label: {
                    Label(renaming ? L("Done") : L("Speakers"), systemImage: "person.2").font(HandyFont.caption)
                }.buttonStyle(.bordered)
            }
            if renaming {
                ForEach(speakers.indices, id: \.self) { i in
                    TextField(L("Name"), text: Binding(get: { speakers[i] }, set: { speakers[i] = $0 }))
                        .textFieldStyle(.handy)
                }
                if speakers.count < 6 {
                    Button(L("Add a speaker")) { speakers.append("Speaker \(speakers.count + 1)") }
                        .textButton().font(HandyFont.caption)
                }
            }
            Text(L("Tap a name to tag who said each part."))
                .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            ForEach(paragraphs.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: HandySpacing.s4) {
                    Button { cycle(i) } label: {
                        Text(speakerOf[i].map { name($0) } ?? L("Who said this?"))
                            .font(HandyFont.caption)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(speakerOf[i] == nil ? HandyColor.surface : HandyColor.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(speakerOf[i] == nil ? HandyColor.textSecondary : HandyColor.accent)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 32)
                    .accessibilityLabel(L("Speaker for this paragraph"))
                    Text(paragraphs[i]).font(HandyFont.body).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(spacing: HandySpacing.s8) {
                ShareLink(item: export) { Label(L("Share organized"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .secondaryButton()
                Button { Copier.copy(export) } label: {
                    Image(systemName: "doc.on.doc").accessibilityLabel(L("Copy")).frame(width: 36, height: 36)
                }.compactButton()
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onAppear { rebuild() }
        .onChange(of: text) { _, _ in rebuild() }
    }

    private func name(_ i: Int) -> String {
        let n = speakers.indices.contains(i) ? speakers[i].trimmingCharacters(in: .whitespaces) : ""
        return n.isEmpty ? "Speaker \(i + 1)" : n
    }

    /// none → speaker 1 → speaker 2 → … → none
    private func cycle(_ p: Int) {
        if let s = speakerOf[p] { speakerOf[p] = s + 1 < speakers.count ? s + 1 : nil } else { speakerOf[p] = 0 }
    }

    private func rebuild() {
        paragraphs = TranscriptTidy.paragraphs(text)
        speakerOf = [:]
    }

    private var export: String {
        paragraphs.indices.map { i in speakerOf[i].map { "\(name($0)): \(paragraphs[i])" } ?? paragraphs[i] }
            .joined(separator: "\n\n")
    }
}

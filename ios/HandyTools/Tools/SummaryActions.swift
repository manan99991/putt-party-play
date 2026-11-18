import SwiftUI

/// Small "Listen" + "Save to Notes" pair for any summary, to-do list or result text. Listen reads it
/// aloud in the best on-device voice (tap again to stop). Save to Notes opens the share sheet with a
/// title, where Notes, Reminders, Mail or Files are one tap away — iOS lets no app write into Notes
/// directly, so this is the honest shortest path.
struct SummaryActions: View {
    let title: String
    let text: String
    var compact = false
    @StateObject private var speaker = Speaker()

    var body: some View {
        HStack(spacing: compact ? HandySpacing.s4 : HandySpacing.s8) {
            Button {
                if speaker.speaking { speaker.stop() } else { speaker.say(text) }
            } label: {
                if compact {
                    Image(systemName: speaker.speaking ? "stop.circle" : "speaker.wave.2").frame(width: 36, height: 36)
                } else {
                    Label(speaker.speaking ? L("Stop") : L("Listen"), systemImage: speaker.speaking ? "stop.circle" : "speaker.wave.2")
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityLabel(speaker.speaking ? L("Stop reading") : L("Read aloud"))
            .modifier(StyleFor(compact: compact))

            ShareLink(item: text, subject: Text(title), preview: SharePreview(title)) {
                if compact {
                    Image(systemName: "note.text.badge.plus").frame(width: 36, height: 36)
                } else {
                    Label(L("Save to Notes"), systemImage: "note.text.badge.plus").frame(maxWidth: .infinity)
                }
            }
            .accessibilityLabel(L("Save to Notes or share"))
            .modifier(StyleFor(compact: compact))
        }
        .onDisappear { speaker.stop() }
    }

    private struct StyleFor: ViewModifier {
        let compact: Bool
        @ViewBuilder func body(content: Content) -> some View {
            if compact { content.buttonStyle(.plain).foregroundStyle(HandyColor.accent) } else { content.secondaryButton() }
        }
    }
}

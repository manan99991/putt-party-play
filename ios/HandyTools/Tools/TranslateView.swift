import SwiftUI
import UIKit

#if canImport(Translation)
import Translation
#endif

/// Instant translation using Apple's own on-device Translation engine — every language it supports,
/// works offline once a language is downloaded, and nothing is sent to us. Type or paste, translate.
struct TranslateView: View {
    @EnvironmentObject var store: StoreManager
    @State private var text = ""
    @State private var present = false
    @State private var errorText: String?

    private var overQuota: Bool { !Usage.hasRoom("translate", limit: Limits.freeTranslatePerDay) }

    var body: some View {
        ToolPage(title: "Translate", subtitle: "Any language, powered by your phone — works offline, stays private.") {
            VStack(spacing: HandySpacing.s8) {
                TextEditor(text: $text)
                    .frame(minHeight: 160).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                    .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty { Text("Type or paste text in any language…").foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) }
                    }
                HStack {
                    Button("Paste") { if let s = UIPasteboard.general.string { text = s } }.compactButton()
                    if !text.isEmpty { Button("Clear") { text = "" }.textButton() }
                    Spacer()
                }
            }

            if !store.isPremium { QuotaChip(name: "translate", limit: Limits.freeTranslatePerDay).environmentObject(store) }
            if overQuota { LimitReachedBanner(message: "You've used today's \(Limits.freeTranslatePerDay) free translations.") }

            Button {
                guard Usage.use("translate", limit: Limits.freeTranslatePerDay) else { return }
                present = true
            } label: {
                Label("Translate", systemImage: "character.bubble").frame(maxWidth: .infinity)
            }
            .primaryButton()
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || overQuota)

            if let errorText { Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

            #if !canImport(Translation)
            Text("Translation needs iOS 17.4 or newer.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            #endif
        }
        .modifier(TranslatePresenter(isPresented: $present, text: text))
    }
}

/// Wraps the system translation sheet behind an availability check so the view compiles on any SDK.
private struct TranslatePresenter: ViewModifier {
    @Binding var isPresented: Bool
    let text: String
    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else { content }
        #else
        content
        #endif
    }
}

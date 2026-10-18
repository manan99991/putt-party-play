import SwiftUI
import PhotosUI
import UIKit

import ImagePlayground

/// How a Page-3 AI tool takes its input.
enum AIInputKind {
    case text          // user types or pastes text
    case imageText     // user picks a photo; we OCR it, then the model works on the text
    case imageVision   // user picks a photo; we classify it, then the model phrases it
    case imageGen      // user describes something; Image Playground makes a picture
}

struct AISpec: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let instructions: String   // the model's role
    let kind: AIInputKind
    let actionLabel: String         // verb on the primary "do it" button (e.g. "Explain this screen")
    var pickLabel: String = "Choose a photo"   // verb on the photo picker, image tools only
    var textPlaceholder: String = "Type or paste here…"
    var promptPrefix: String = ""   // prepended to the (text or OCR'd) content before the model sees it
}

/// The one spec table that defines all ten AI tools. Adding a tool is one entry here.
@MainActor
func aiSpec(for id: String) -> AISpec? {
    switch id {
    case "ai_summarize":
        return AISpec(id: id, title: "Summarize", subtitle: "Long text in, the gist out — on your phone.",
                      instructions: "You summarize text clearly and briefly. Return 3–5 tight bullet points capturing the key facts and any action items. No preamble.",
                      kind: .text, actionLabel: "Summarize", textPlaceholder: "Paste an article, email, or notes…")
    case "ai_extract":
        return AISpec(id: id, title: "Extract to Data", subtitle: "Receipt, business card, poster → clean fields.",
                      instructions: "You extract structured data from messy text. Identify what it is (receipt, business card, event, etc.) and return the key fields as a clean 'Label: value' list. Include totals, dates, names, phone, email, address when present. No commentary.",
                      kind: .imageText, actionLabel: "Pull out the details", pickLabel: "Choose a photo")
    case "ai_rewrite":
        return AISpec(id: id, title: "Rewrite & Tone", subtitle: "Say it better — clearer, shorter, friendlier.",
                      instructions: "You rewrite the user's text to be clear, natural and well-structured while keeping their meaning and voice. Fix grammar and flow. Return only the rewritten text.",
                      kind: .text, actionLabel: "Rewrite", textPlaceholder: "Paste the text you want to improve…")
    case "ai_ask":
        return AISpec(id: id, title: "Ask a Screenshot", subtitle: "Confused by a screen? Get a plain answer.",
                      instructions: "You explain what's on a screen in plain language and tell the user what it means and what, if anything, they should do next. Be concise and practical.",
                      kind: .imageText, actionLabel: "Explain this screen", pickLabel: "Choose a screenshot",
                      promptPrefix: "This is the text read from a screenshot. Explain what it means and what to do next:\n\n")
    case "ai_proofread":
        return AISpec(id: id, title: "Proofread", subtitle: "Catch typos and clunky grammar before you send.",
                      instructions: "You proofread text. Return the corrected version, then a short list of the notable changes you made. Keep the author's voice.",
                      kind: .text, actionLabel: "Proofread", textPlaceholder: "Paste the text to check…")
    case "ai_describe":
        return AISpec(id: id, title: "Describe Image", subtitle: "A natural caption / alt-text for any photo.",
                      instructions: "You write a single natural, vivid sentence describing a photo for accessibility (alt-text), based on the detected labels. Don't list the labels; write real prose.",
                      kind: .imageVision, actionLabel: "Write the caption", pickLabel: "Choose a photo")
    case "ai_handwriting":
        return AISpec(id: id, title: "Handwriting → Text", subtitle: "Turn a photo of notes into typed text.",
                      instructions: "You clean up text that was read from handwriting. Fix obvious recognition errors and restore natural line breaks and punctuation. Return only the cleaned text.",
                      kind: .imageText, actionLabel: "Convert to text", pickLabel: "Choose a photo of notes")
    case "ai_reply":
        return AISpec(id: id, title: "Draft a Reply", subtitle: "Paste a message, get a ready-to-send reply.",
                      instructions: "You draft a friendly, appropriate reply to the message the user pastes. Match its formality. Keep it concise. Return only the reply.",
                      kind: .text, actionLabel: "Draft reply", textPlaceholder: "Paste the message you received…")
    case "ai_identify":
        return AISpec(id: id, title: "Identify", subtitle: "Point it at a plant, object, or landmark.",
                      instructions: "You identify what something is from detected image labels and tell the user one or two genuinely useful facts about it. Be confident but note if you're unsure.",
                      kind: .imageVision, actionLabel: "Identify it", pickLabel: "Choose a photo")
    case "ai_sticker":
        return AISpec(id: id, title: "Make a Sticker", subtitle: "Describe it — your phone draws it.",
                      instructions: "", kind: .imageGen, actionLabel: "Describe your sticker",
                      textPlaceholder: "a happy corgi wearing sunglasses…")
    default:
        return nil
    }
}

/// Generic Page-3 AI tool screen. One view powers all ten, driven by its `AISpec`.
struct AIToolView: View {
    let spec: AISpec
    @EnvironmentObject var store: StoreManager

    @State private var text = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var output = ""
    @State private var labels: [String] = []
    @State private var working = false
    @State private var errorText: String?
    @State private var showPlayground = false
    @State private var genImage: UIImage?

    private var quotaExhausted: Bool { !Usage.hasRoom("ai", limit: Limits.freeAiPerDay) }

    var body: some View {
        ToolPage(title: spec.title, subtitle: spec.subtitle) {
            // Availability banner — graceful fallback when on-device AI isn't present.
            if !AIEngine.isAvailable && spec.kind != .imageVision {
                fallbackCard
            }

            if spec.kind == .imageGen {
                imageGenBody
            } else {
                if spec.kind == .text {
                    textInput
                } else {
                    photoInput
                }

                // The primary action appears once there's something to act on: text tools always,
                // photo tools only after a photo is chosen. That keeps one clear next step per screen.
                if spec.kind == .text || pickedImage != nil {
                    if !store.isPremium {
                        QuotaChip(name: "ai", limit: Limits.freeAiPerDay).environmentObject(store)
                    }
                    if quotaExhausted {
                        LimitReachedBanner(message: "You've used today's \(Limits.freeAiPerDay) free AI actions.")
                    }

                    Button {
                        run()
                    } label: {
                        HStack {
                            if working { ProgressView().tint(.white) }
                            Text(working ? "Working…" : spec.actionLabel)
                        }.frame(maxWidth: .infinity)
                    }
                    .primaryButton()
                    .disabled(working || quotaExhausted || !canRun)
                }
            }

            if let errorText {
                Text(errorText).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
            }

            if !output.isEmpty {
                resultCard
            } else if !labels.isEmpty && !AIEngine.isAvailable {
                // Vision still works without Apple Intelligence — show the raw read as a useful fallback.
                resultCard
            }
        }
    }

    // MARK: inputs

    private var textInput: some View {
        VStack(spacing: HandySpacing.s8) {
            TextEditor(text: $text)
                .frame(minHeight: 150)
                .padding(HandySpacing.s8)
                .scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty { Text(spec.textPlaceholder).foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false) }
                }
            HStack {
                Button("Paste") { if let s = UIPasteboard.general.string { text = s } }.compactButton()
                if !text.isEmpty { Button("Clear") { text = ""; output = "" }.textButton() }
                Spacer()
            }
        }
    }

    private var photoInput: some View {
        VStack(spacing: HandySpacing.s12) {
            if let img = pickedImage {
                // Chosen: show it, with a quiet way to swap. The blue action button sits below.
                Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a different photo", systemImage: "photo.on.rectangle.angled")
                }
                .textButton()
            } else {
                // Empty: a single prominent call to action — the one thing to do next.
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(spec.pickLabel, systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                }
                .secondaryButton()
            }
        }
        .onChange(of: pickedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    pickedImage = img; output = ""; labels = []
                }
            }
        }
    }

    private var imageGenBody: some View {
        VStack(spacing: HandySpacing.s12) {
            textInput
            Button { showPlayground = true } label: {
                Label("Create sticker", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
            }
            .primaryButton()
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            .imagePlaygroundSheet(isPresented: $showPlayground, concept: text) { url in
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) { genImage = img; HandyHaptics.success() }
            }
            if let genImage, let png = genImage.pngData() {
                Image(uiImage: genImage).resizable().scaledToFit().frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                ShareLink(item: PNGFile(data: png), preview: SharePreview("Sticker")) {
                    Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.primaryButton()
            }
        }
    }

    // MARK: result

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            Text(output.isEmpty ? labels.joined(separator: ", ") : output)
                .font(HandyFont.body).foregroundStyle(HandyColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            HStack {
                Button { UIPasteboard.general.string = output.isEmpty ? labels.joined(separator: ", ") : output; HandyHaptics.success() } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }.compactButton()
                ShareLink(item: output.isEmpty ? labels.joined(separator: ", ") : output) { Label("Share", systemImage: "square.and.arrow.up") }.compactButton()
                Spacer()
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("On-device AI not available", systemImage: "sparkles.slash").font(HandyFont.bodyStrong)
            Text(AIEngine.availabilityReason).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if spec.kind == .imageText {
                Text("You can still read the text from the photo below — that works on every iPhone.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: run

    private var canRun: Bool {
        switch spec.kind {
        case .text, .imageGen: return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .imageText, .imageVision: return pickedImage != nil
        }
    }

    private func run() {
        errorText = nil; output = ""; labels = []
        working = true
        Task {
            defer { working = false }
            do {
                switch spec.kind {
                case .text:
                    try consume()
                    output = try await AIEngine.run(instructions: spec.instructions, prompt: spec.promptPrefix + text)
                case .imageText:
                    guard let img = pickedImage else { return }
                    let read = await AIEngine.recognizeText(img)
                    guard !read.isEmpty else { errorText = "Couldn't find any text in that image."; return }
                    if AIEngine.isAvailable {
                        try consume()
                        output = try await AIEngine.run(instructions: spec.instructions, prompt: spec.promptPrefix + read)
                    } else {
                        // Fallback: still deliver the read text.
                        output = read
                    }
                case .imageVision:
                    guard let img = pickedImage else { return }
                    labels = await AIEngine.classify(img)
                    guard !labels.isEmpty else { errorText = "Couldn't recognize what's in that image."; return }
                    if AIEngine.isAvailable {
                        try consume()
                        output = try await AIEngine.run(instructions: spec.instructions,
                                                        prompt: "Detected labels: \(labels.joined(separator: ", ")).")
                    }
                    // else: labels array renders as the fallback result.
                case .imageGen:
                    break
                }
                HandyHaptics.success()
            } catch let e as AIEngine.AIError {
                errorText = e.errorDescription
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func consume() throws {
        guard Usage.use("ai", limit: Limits.freeAiPerDay) else { throw AIEngine.AIError.empty }
    }
}

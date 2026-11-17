import SwiftUI

/// The result card for "What is this?" — an honest read of the best guess with how sure it is, any writing
/// or barcode found on the thing, and one-tap next steps tuned to what it is (a plant's care, where to buy a
/// product, a landmark in Maps). Every next step is a web search you choose to open; nothing leaves the phone
/// until you tap. When the picture is really a group of people, it says so instead of naming an object.
struct IdentifyResult: View {
    let text: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if isScene { scene } else { answer }
            CopyButton(text: text)
        }
    }

    // MARK: - The honest answer

    private var answer: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            VStack(alignment: .leading, spacing: HandySpacing.s4) {
                if sure {
                    Text(label ?? "").font(HandyFont.title)
                    if let c = confidence {
                        Text("\(c)% sure").font(HandyFont.caption)
                            .foregroundStyle(c >= 70 ? HandyColor.accent : HandyColor.amber)
                    }
                } else {
                    Text("Not sure — closest guesses").font(HandyFont.body).foregroundStyle(HandyColor.amber)
                    if let label { Text(label).font(HandyFont.title) }
                }
                if let also { Text("Also: \(also)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            if let ocr { Label("Reads: \(ocr)", systemImage: "text.viewfinder").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            if let barcode { Label(barcode, systemImage: "barcode").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }

            // Next steps — web hand-offs, so nothing leaves the phone until you tap one.
            VStack(spacing: HandySpacing.s8) {
                if sure {
                    if let first = actions.first, let url = first.url {
                        Button { openURL(url) } label: { Label(first.title, systemImage: first.icon).frame(maxWidth: .infinity) }.primaryButton()
                    }
                    ForEach(actions.dropFirst()) { a in
                        if let url = a.url {
                            Button { openURL(url) } label: { Label(a.title, systemImage: a.icon).frame(maxWidth: .infinity) }.secondaryButton()
                        }
                    }
                    if let url = confirmURL {
                        Button { openURL(url) } label: { Label("Confirm on the web", systemImage: "magnifyingglass").frame(maxWidth: .infinity) }.secondaryButton()
                    }
                } else {
                    if let url = confirmURL {
                        Button { openURL(url) } label: { Label("Search the web", systemImage: "magnifyingglass").frame(maxWidth: .infinity) }.primaryButton()
                    }
                    ForEach(actions) { a in
                        if let url = a.url {
                            Button { openURL(url) } label: { Label(a.title, systemImage: a.icon).frame(maxWidth: .infinity) }.secondaryButton()
                        }
                    }
                }
            }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - A people / scene, not an object

    private var scene: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Label("A photo of people", systemImage: "person.2").font(HandyFont.body)
            Text(text).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Parsing the formatted result text

    private var lines: [String] { text.components(separatedBy: "\n") }
    private func value(_ prefix: String) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
    private var topLine: String? { value("Most likely:") }
    private var label: String? { topLine?.components(separatedBy: " — ").first?.trimmingCharacters(in: .whitespaces) }
    private var confidence: Int? {
        guard let tail = topLine?.components(separatedBy: " — ").last else { return nil }
        return Int(tail.filter { $0.isNumber })
    }
    private var also: String? { value("Also:") }
    private var ocr: String? { value("Text:") }
    private var barcode: String? { value("Barcode:") }
    private var isScene: Bool { topLine == nil && barcode == nil }
    private var sure: Bool { (confidence ?? 0) >= 45 }

    private var confirmURL: URL? {
        let q = [label, ocr].compactMap { $0 }.joined(separator: " ")
        return q.isEmpty ? nil : search(q)
    }

    // MARK: - Category-smart next steps

    private struct Act: Identifiable { let title: String; let icon: String; let url: URL?; var id: String { title } }

    private var actions: [Act] {
        guard let label else { return [] }
        switch Identifier.categoryFor(label, animal: false, barcode: barcode != nil) {
        case .plant:   return [Act(title: "Care & is it pet-safe", icon: "leaf", url: search("\(label) plant care toxic to pets"))]
        case .animal:  return [Act(title: "About this breed", icon: "pawprint", url: search("\(label) breed facts temperament"))]
        case .food:    return [Act(title: "What it is & recipe", icon: "fork.knife", url: search("\(label) recipe"))]
        case .product:
            var a = [Act(title: "Where to buy", icon: "cart", url: search("\(label) buy price"))]
            if let code = barcode?.components(separatedBy: " ").first, !code.isEmpty { a.append(Act(title: "Look up barcode", icon: "barcode", url: search(code))) }
            return a
        case .vehicle: return [Act(title: "About this", icon: "car", url: search(label))]
        case .place:   return [Act(title: "Open in Maps", icon: "map", url: maps(label)), Act(title: "Facts", icon: "info.circle", url: search(label))]
        case .money:   return [Act(title: "Identify & value", icon: "dollarsign.circle", url: search("\(label) value"))]
        case .art:     return [Act(title: "About this work", icon: "paintpalette", url: search(label))]
        case .object:  return []
        }
    }

    private func search(_ q: String) -> URL? {
        guard let s = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.google.com/search?q=\(s)")
    }
    private func maps(_ q: String) -> URL? {
        guard let s = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(s)")
    }
}

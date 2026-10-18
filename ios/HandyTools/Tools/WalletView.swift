import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Keep your loyalty and membership barcodes in one place so you stop digging through your real
/// wallet at the till. Stored only on this phone. Tap a card to show it big and bright for scanning.
struct WalletView: View {
    @EnvironmentObject var store: StoreManager
    @State private var cards: [LoyaltyCard] = WalletStore.load()
    @State private var adding = false
    @State private var showing: LoyaltyCard?

    private var atLimit: Bool { !store.isPremium && cards.count >= Limits.freeWalletCards }

    var body: some View {
        ToolPage(title: "Card Wallet", subtitle: "Every loyalty card's barcode, ready to scan.") {
            if cards.isEmpty {
                VStack(spacing: HandySpacing.s12) {
                    Image(systemName: "creditcard.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
                    Text("Add a card's number once. Show its barcode anytime — even offline.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s24)
            } else {
                ForEach(cards) { card in
                    Button { showing = card } label: {
                        HStack {
                            Image(systemName: card.isQR ? "qrcode" : "barcode").foregroundStyle(HandyColor.accent).frame(width: 32)
                            VStack(alignment: .leading) {
                                Text(card.name).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                                Text(card.code).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(HandyColor.textSecondary)
                        }.cardStyle(padding: HandySpacing.s12)
                    }.buttonStyle(.plain)
                }
                .onDelete { idx in cards.remove(atOffsets: idx); WalletStore.save(cards) }
            }

            if atLimit { LimitReachedBanner(message: "Free keeps \(Limits.freeWalletCards) cards. Go Pro for unlimited.") }

            Button { adding = true } label: { Label("Add a card", systemImage: "plus").frame(maxWidth: .infinity) }
                .primaryButton().disabled(atLimit)
        }
        .sheet(isPresented: $adding) { AddCardSheet { new in cards.append(new); WalletStore.save(cards) } }
        .sheet(item: $showing) { card in CardDisplaySheet(card: card) }
    }
}

struct LoyaltyCard: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var code: String
    var isQR: Bool
}

private struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var code = ""
    @State private var isQR = false
    let onSave: (LoyaltyCard) -> Void
    var body: some View {
        NavigationStack {
            Form {
                TextField("Card name (e.g. Tesco Clubcard)", text: $name)
                TextField("Card number / code", text: $code).autocorrectionDisabled().textInputAutocapitalization(.characters)
                Toggle("This is a QR code", isOn: $isQR)
            }
            .navigationTitle("Add card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(LoyaltyCard(name: name.isEmpty ? "Card" : name, code: code, isQR: isQR)); dismiss() }
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }.presentationDetents([.medium])
    }
}

private struct CardDisplaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: LoyaltyCard
    @State private var priorBrightness = UIScreen.main.brightness
    var body: some View {
        VStack(spacing: HandySpacing.s24) {
            Text(card.name).font(.system(size: 24, weight: .bold))
            if let img = Barcode.make(card.code, qr: card.isQR) {
                Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
                    .frame(maxHeight: card.isQR ? 240 : 160).padding(HandySpacing.s16)
                    .background(.white, in: RoundedRectangle(cornerRadius: HandyRadius.card))
            }
            Text(card.code).font(HandyFont.body).foregroundStyle(HandyColor.textSecondary)
            Spacer()
            Button("Done") { dismiss() }.primaryButton()
        }
        .padding(HandySpacing.s24)
        .onAppear { UIScreen.main.brightness = 1.0 }
        .onDisappear { UIScreen.main.brightness = priorBrightness }
    }
}

/// CoreImage barcode/QR generator.
enum Barcode {
    static func make(_ string: String, qr: Bool) -> UIImage? {
        let data = Data(string.utf8)
        let filter: CIFilter
        if qr { let f = CIFilter.qrCodeGenerator(); f.message = data; f.correctionLevel = "M"; filter = f }
        else { let f = CIFilter.code128BarcodeGenerator(); f.message = data; filter = f }
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum WalletStore {
    private static let key = "wallet.cards"
    static func load() -> [LoyaltyCard] {
        guard let d = UserDefaults.standard.data(forKey: key), let c = try? JSONDecoder().decode([LoyaltyCard].self, from: d) else { return [] }
        return c
    }
    static func save(_ cards: [LoyaltyCard]) {
        if let d = try? JSONEncoder().encode(cards) { UserDefaults.standard.set(d, forKey: key) }
    }
}

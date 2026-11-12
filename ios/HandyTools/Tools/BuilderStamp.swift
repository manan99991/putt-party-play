import SwiftUI

/// Settings for the "Sign and stamp" step: choose what goes on the page, draw the signature once, and drag each
/// mark to its place on a sample page. The places are remembered, so the tool stamps the same spots every time.
struct StampEditor: View {
    @Binding var marks: String
    /// What the page looks like at this point in the tool (a sample), or nil for a blank sheet.
    let page: UIImage?
    @State private var signature = DocEngine.savedSignature
    @State private var name = StampBook.name
    @State private var showPad = false

    private var plan: StampPlan { StampPlan(marks) }

    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            ForEach(StampPlan.Mark.allCases, id: \.self) { m in
                Toggle(m.title, isOn: Binding(get: { plan.has(m) }, set: { on in var p = plan; p.set(m, on: on); marks = p.text }))
                    .font(HandyFont.caption).accessibilityIdentifier("stamp-\(m.rawValue)")
            }
            if plan.has(.signature) {
                Button { showPad = true } label: { Label(signature == nil ? "Draw my signature" : "Redraw my signature", systemImage: "signature") }
                    .font(HandyFont.caption).accessibilityIdentifier("stamp-draw")
                if signature == nil {
                    Text("Draw it once. It is saved on this phone and used by every tool.").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            if plan.has(.name) {
                TextField("Your name as it should appear", text: $name)
                    .font(HandyFont.caption).padding(HandySpacing.s8).background(HandyColor.bg, in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: name) { _, v in StampBook.name = v }
            }
            if !plan.spots.isEmpty {
                board
                Text("Drag each one to where it belongs. The tool puts them in the same place every time.")
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .sheet(isPresented: $showPad) { SignaturePadSheet { img in signature = img } }
    }

    private var board: some View {
        let ratio = page.map { $0.size.width / max(1, $0.size.height) } ?? (8.5 / 11)
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let page { Image(uiImage: page).resizable() } else { Color.white }
                ForEach(plan.spots, id: \.mark) { s in chip(s, in: geo.size) }
            }
            .coordinateSpace(name: "stamp-board")
        }
        .aspectRatio(ratio, contentMode: .fit)
        .frame(maxHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(HandyColor.border, lineWidth: 1))
    }

    private func chip(_ s: StampPlan.Spot, in size: CGSize) -> some View {
        Text(s.mark.short)
            .font(HandyFont.micro).foregroundStyle(.white).lineLimit(1)
            .frame(width: max(60, s.w * size.width), height: 30)
            .background(HandyColor.accent.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("\(s.mark.short), drag to place")
            // The drag is attached to the chip itself (before it is positioned) so only the chip catches the finger.
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("stamp-board")).onChanged { g in
                guard size.width > 0, size.height > 0 else { return }
                var p = plan
                p.move(s.mark, x: g.location.x / size.width, y: g.location.y / size.height)
                marks = p.text
            })
            .position(x: s.x * size.width, y: s.y * size.height)
    }
}

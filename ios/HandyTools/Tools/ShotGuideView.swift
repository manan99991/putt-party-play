import SwiftUI
import PDFKit

/// Guided shots: pick the job, take each shot the screen asks for (with how to frame it), then get one dated,
/// place-stamped PDF to send — and the photos in Photos.
struct ShotGuideView: View {
    @State private var job: ShotGuide.Job?
    @State private var taken: [Int: ShotGuide.Taken] = [:]
    @State private var current = 0
    @State private var camera = false
    @State private var started = Date()
    @State private var place: String?
    @StateObject private var whereAmI = WhereAmI()
    @State private var pdf: Data?
    @State private var savedCount: Int?

    var body: some View {
        ToolPage(title: "Guided shots", subtitle: "Every angle that matters, stamped with the time and place, in one PDF you can send.") {
            if let job { shooting(job) } else { chooser }
        }
        .fullScreenCover(isPresented: $camera) {
            SelfieCamera(front: false) { img in
                camera = false
                guard let img, let job else { return }
                taken[current] = ShotGuide.Taken(shot: job.shots[current], image: img.normalizedUp(), at: Date())
                if let next = (current + 1..<job.shots.count).first(where: { taken[$0] == nil }) { current = next }
                pdf = nil
            }.ignoresSafeArea()
        }
    }

    private var chooser: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text(L("What are you photographing?")).font(HandyFont.bodyStrong)
            ForEach(ShotGuide.jobs) { j in
                Button {
                    job = j; taken = [:]; current = 0; started = Date(); pdf = nil; savedCount = nil
                    whereAmI.find { text in place = text?.components(separatedBy: "\n").first }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: j.icon).font(.system(size: 20)).foregroundStyle(HandyColor.accent).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(j.title)).font(HandyFont.body.weight(.semibold)).foregroundStyle(HandyColor.textPrimary)
                            Text("\(L(j.line)) · \(j.shots.count) \(L("shots"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: 0)
                }.buttonStyle(.plain).accessibilityIdentifier("shotguide-\(j.id)")
            }
        }
    }

    @ViewBuilder private func shooting(_ job: ShotGuide.Job) -> some View {
        let done = taken.count
        HStack {
            Label(L(job.title), systemImage: job.icon).font(HandyFont.bodyStrong)
            Spacer()
            Button(L("Change")) { self.job = nil }.textButton()
        }
        ProgressView(value: Double(done), total: Double(job.shots.count)).tint(HandyColor.accent)
        Text("\(done) \(L("of")) \(job.shots.count) \(L("taken"))\(place.map { " · \($0)" } ?? (whereAmI.looking ? " · " + L("finding where you are…") : ""))")
            .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        if current < job.shots.count {
            let s = job.shots[current]
            VStack(alignment: .leading, spacing: 6) {
                Text("\(L("Shot")) \(current + 1): \(L(s.name))").font(.system(size: 22, weight: .bold, design: .rounded))
                Label(L(s.tip), systemImage: "lightbulb").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                HStack {
                    Button { camera = true } label: { Label(L(taken[current] == nil ? "Take it" : "Retake"), systemImage: "camera.fill").frame(maxWidth: .infinity) }
                        .primaryButton().accessibilityIdentifier("shotguide-take")
                    Button(L("Skip")) { current = min(job.shots.count - 1, current + 1) }.secondaryButton()
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(job.shots.indices, id: \.self) { i in
                Button { current = i } label: {
                    ZStack(alignment: .bottomLeading) {
                        if let t = taken[i] { Image(uiImage: t.image).resizable().scaledToFill() }
                        else { Rectangle().fill(HandyColor.border.opacity(0.3)) }
                        Text("\(i + 1). \(L(job.shots[i].name))").font(.system(size: 10, weight: .semibold)).lineLimit(2)
                            .padding(4).background(.black.opacity(0.55)).foregroundStyle(.white)
                    }
                    .frame(height: 96).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(i == current ? HandyColor.accent : .clear, lineWidth: 2.5))
                }.buttonStyle(.plain)
            }
        }
        if done > 0 {
            Button { makeReport(job) } label: { Label("\(L("Make the PDF")) (\(done) \(L(done == 1 ? "photo" : "photos")))", systemImage: "doc.richtext").frame(maxWidth: .infinity) }
                .primaryButton().accessibilityIdentifier("shotguide-pdf")
            if done < job.shots.count { Text(L("Shots you skipped are simply left out.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
        }
        if let pdf {
            PDFPreview(data: pdf).frame(height: 360).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            ShareLink(item: PDFFile(data: pdf), preview: SharePreview("\(job.title).pdf")) { Label(L("Send or save the PDF"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                .primaryButton()
            Button {
                Task {
                    var n = 0
                    for i in taken.keys.sorted() { if let t = taken[i], let d = ShotGuide.stamp(t.image, text: ShotGuide.stampText(t.shot, at: t.at, place: place)).jpegData(compressionQuality: 0.9), await PhotoSaver.save(d) { n += 1 } }
                    savedCount = n; if n > 0 { HandyHaptics.success() }
                }
            } label: { Label(L(savedCount == nil ? "Save the stamped photos to Photos" : "Saved \(savedCount!) to Photos"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                .secondaryButton()
        }
    }

    private func makeReport(_ job: ShotGuide.Job) {
        let list = taken.keys.sorted().compactMap { taken[$0] }
        let p = place, s = started
        Task {
            let d = await Task.detached(priority: .userInitiated) { ShotGuide.report(job, taken: list, place: p, started: s) }.value
            pdf = d; HandyHaptics.success()
        }
    }
}

struct PDFPreview: UIViewRepresentable {
    let data: Data
    final class Shown { var data: Data?; init() {} }
    func makeCoordinator() -> Shown { Shown() }
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true; v.displayMode = .singlePageContinuous
        v.document = PDFDocument(data: data); context.coordinator.data = data; return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        guard context.coordinator.data != data else { return }
        context.coordinator.data = data; v.document = PDFDocument(data: data)
    }
}

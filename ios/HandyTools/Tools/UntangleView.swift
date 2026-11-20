import SwiftUI
import PhotosUI
import MapKit

/// Untangle — tell it what's on your plate any way you like (type, talk, paste, a screenshot) and how
/// you feel. It builds a plan around YOU: gentle start and rests when you're low or unwell, the trip out
/// while you still have energy, nearby stores and pharmacies with drive time, why each step sits where it
/// does and how it'll feel after. Then it keeps up: Done / +10 min / Skip re-times the rest, a nudge
/// arrives as each step starts, and the whole plan goes to Reminders in one tap.
struct UntangleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechStream()
    @StateObject private var nearby = NearbyPlaces()

    @State private var input = ""
    @State private var shot: PhotosPickerItem?
    @State private var reading = false
    @State private var plan: UntanglePlan.Plan?
    @State private var detail: UntanglePlan.Detail = .balanced
    @State private var energy: UntanglePlan.Energy?          // nil = let Tenzy read it
    @State private var startIn = 0                           // minutes from now
    @State private var expanded: Set<UUID> = []
    @State private var note: String?
    @State private var errorText: String?
    @State private var nudges = false
    @State private var notifOff = false
    @State private var tick = Date()
    @State private var arrivals: Set<String> = []          // "show my list when I get here" alerts that are set
    @State private var cardImage: UIImage?                    // the plan as a picture, while the share sheet is up
    @FocusState private var focused: Bool

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// true when pushed inside the app's own navigation (Describe it, search); false as its own sheet.
    var embedded = false
    /// A to-do list handed over from Think it through: planned as soon as the screen opens.
    var seed = ""
    /// What was typed is worries, a decision or a question, not things to do: answered by Think it through instead.
    @State private var thinkAbout: String?

    private var page: some View {
        ToolPage(title: "Plan my day", subtitle: "Your to-do list → a timed plan built around how you feel today.", working: reading) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                inputCard
                if let p = plan { planView(p) }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
    }

    var body: some View {
        Group {
            if embedded { page }
            else {
                NavigationStack {
                    page.toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { speech.stop(); dismiss() } } }
                }
            }
        }
        .onChange(of: speech.transcript) { _, t in if speech.running, !t.isEmpty { input = t } }
        .onChange(of: shot) { _, item in readShot(item) }
        .onChange(of: detail) { _, _ in if plan != nil { build() } }
        .onChange(of: energy) { _, _ in if plan != nil { build() } }
        .onChange(of: startIn) { _, _ in if plan != nil { build() } }
        .onReceive(timer) { tick = $0 }
        .onDisappear { speech.stop() }
        .onAppear { if !seed.isEmpty, input.isEmpty { input = seed; build() } }
        .sheet(item: Binding(get: { thinkAbout.map(ThinkSeed.init) }, set: { thinkAbout = $0?.text })) { s in
            NavigationStack {
                ThinkBoxView(seed: s.text)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { thinkAbout = nil } } }
            }
        }
    }

    // MARK: - Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            TextEditor(text: $input).focused($focused)
                .frame(minHeight: plan == nil ? 130 : 70).padding(HandySpacing.s8).scrollContentBackground(.hidden)
                .background(HandyColor.surface, in: RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(focused || speech.running ? HandyColor.accent : HandyColor.border, lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text(L("Everything you need to do today, and how you feel — e.g. \"Shower, groceries, office work, not feeling well\""))
                            .foregroundStyle(HandyColor.textSecondary).padding(HandySpacing.s12).allowsHitTesting(false)
                    }
                }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HandySpacing.s8) {
                    Button { speech.running ? speech.stop() : speech.start() } label: {
                        Label(speech.running ? L("Stop") : L("Talk"), systemImage: speech.running ? "stop.circle.fill" : "mic.fill")
                    }.compactButton()
                    PhotosPicker(selection: $shot, matching: .images) { Label(L("Screenshot"), systemImage: "text.viewfinder") }.compactButton()
                    Button { if let s = Clipboard.text { input = s } } label: { Label(L("Paste"), systemImage: "doc.on.clipboard") }.compactButton()
                    if !input.isEmpty { Button(L("Clear")) { input = ""; plan = nil; UntangleCheckIns.cancelAll() }.textButton() }
                }
            }
            if speech.running { Text(L("Listening… say everything you need to do, and how you feel.")).font(HandyFont.caption).foregroundStyle(HandyColor.accent) }
            if reading { ToolProgressBar(label: "Reading your screenshot…", showsTime: false) }
            if let e = errorText ?? speech.errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button { speech.stop(); focused = false; build() } label: {
                Label(plan == nil ? L("Make my plan") : L("Re-plan"), systemImage: "sparkles").frame(maxWidth: .infinity)
            }.primaryButton().disabled(trimmed.isEmpty)
        }
    }

    // MARK: - Plan

    private func planView(_ p: UntanglePlan.Plan) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            header(p)
            presets
            if let c = p.careNote {
                Label { Text(L(c)).font(HandyFont.caption) } icon: { Image(systemName: "cross.case.fill").foregroundStyle(HandyColor.danger) }
                    .cardStyle(padding: HandySpacing.s12)
            }
            ForEach(p.steps) { s in stepCard(s, current: s.id == p.remaining.first?.id) }
            footer(p)
        }
    }

    private func header(_ p: UntanglePlan.Plan) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack(alignment: .center, spacing: HandySpacing.s12) {
                ZStack {
                    Circle().stroke(HandyColor.border, lineWidth: 6)
                    Circle().trim(from: 0, to: p.progress).stroke(HandyColor.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(Int(p.progress * 100))%").font(HandyFont.caption.weight(.bold))
                }.frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(L("Done by")) \(p.finishAt.formatted(date: .omitted, time: .shortened))").font(.system(size: 22, weight: .bold))
                    Text("\(duration(p.totalMinutes)) · \(p.steps.filter { !$0.isRest }.count) \(L("steps")) · \(L(p.energy.title))")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
            }
            Text(L(p.encouragement)).font(HandyFont.body).foregroundStyle(HandyColor.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 6) {
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach(UntanglePlan.Detail.allCases, id: \.self) { d in HChip(text: L(d.title), selected: detail == d) { detail = d } }
            }
            HandyFlow(spacing: HandySpacing.s8) {
                HChip(text: L("Read my mood"), selected: energy == nil) { energy = nil }
                ForEach(UntanglePlan.Energy.allCases, id: \.self) { e in HChip(text: L(e.title), selected: energy == e) { energy = e } }
            }
            HandyFlow(spacing: HandySpacing.s8) {
                ForEach([0, 30, 60, 120], id: \.self) { m in
                    HChip(text: m == 0 ? L("Start now") : "\(L("Start in")) \(duration(m))", selected: startIn == m) { startIn = m }
                }
            }
        }
    }

    private func stepCard(_ s: UntanglePlan.Step, current: Bool) -> some View {
        let open = expanded.contains(s.id) || current
        return VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { if expanded.contains(s.id) { expanded.remove(s.id) } else { expanded.insert(s.id) } } label: {
                HStack(alignment: .top, spacing: HandySpacing.s12) {
                    Image(systemName: s.status == .done ? "checkmark.circle.fill" : s.kind.icon)
                        .font(.system(size: 20)).foregroundStyle(s.status == .done ? Color.green : (s.isRest ? HandyColor.textSecondary : HandyColor.accent))
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(s.title)).font(s.isRest ? HandyFont.caption : HandyFont.bodyStrong)
                            .strikethrough(s.status == .done || s.status == .skipped)
                            .foregroundStyle(s.status == .skipped ? HandyColor.textSecondary : HandyColor.textPrimary)
                        Text(timeLine(s)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                    Spacer()
                    if current { Text(L("Now")).font(HandyFont.micro.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3).background(HandyColor.accent, in: Capsule()) }
                }
            }.buttonStyle(.plain)

            if open, !s.isRest, s.status != .skipped {
                Text(L(s.why)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                ForEach(s.substeps, id: \.self) { t in
                    Label { Text(L(t)).font(HandyFont.caption) } icon: { Image(systemName: "circle").font(.system(size: 8)) }
                }
                if !s.items.isEmpty {
                    Text(L("List")).font(HandyFont.micro.weight(.bold)).foregroundStyle(HandyColor.textSecondary)
                    HandyFlow(spacing: 6) { ForEach(s.items, id: \.self) { Text(L($0)).font(HandyFont.caption).padding(.horizontal, 10).padding(.vertical, 4).background(HandyColor.surface, in: Capsule()) } }
                }
                if let q = s.kind.placeQuery { placesBlock(q, step: s) }
                Label { Text(L(s.feel)).font(HandyFont.caption.italic()) } icon: { Image(systemName: "sparkles").foregroundStyle(HandyColor.accent) }
                if s.status != .done { checkIn(s) }
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .overlay(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous).stroke(current ? HandyColor.accent : Color.clear, lineWidth: 2))
        .opacity(s.status == .skipped ? 0.55 : 1)
    }

    private func checkIn(_ s: UntanglePlan.Step) -> some View {
        HStack(spacing: HandySpacing.s8) {
            Button { update { UntanglePlan.markDone(&$0, s.id) }; HandyHaptics.success() } label: { Label(L("Done"), systemImage: "checkmark") }.compactButton()
            Button { update { UntanglePlan.extend(&$0, s.id, by: 10) } } label: { Label(L("+10 min"), systemImage: "clock.arrow.circlepath") }.compactButton()
            Button { update { UntanglePlan.skip(&$0, s.id) } } label: { Text(L("Skip")) }.textButton()
        }
    }

    private func placesBlock(_ q: String, step s: UntanglePlan.Step) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let list = nearby.places[q], !list.isEmpty {
                ForEach(list) { pl in
                    Button { pl.item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]) } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(HandyColor.accent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pl.name).font(HandyFont.caption.weight(.semibold)).foregroundStyle(HandyColor.textPrimary)
                                Text([pl.driveMinutes.map { "\($0) \(L("min drive"))" }, pl.address.isEmpty ? nil : pl.address].compactMap { $0 }.joined(separator: " · "))
                                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.triangle.turn.up.right.circle").foregroundStyle(HandyColor.accent)
                        }
                    }.buttonStyle(.plain)
                    let key = ArrivalAlert.id(pl.name, step: s.id)
                    Button { toggleArrival(pl, step: s) } label: {
                        Label(arrivals.contains(key) ? L("I'll show your list when you get here") : L("Show my list when I get here"),
                              systemImage: arrivals.contains(key) ? "bell.badge.fill" : "bell")
                            .font(HandyFont.micro)
                    }
                    .buttonStyle(.plain).foregroundStyle(HandyColor.accent).padding(.leading, 26)
                    .accessibilityIdentifier("arrive-\(pl.name)")
                }
                if !arrivals.isEmpty {
                    Text(L("iPhone shows the alert once, as you arrive. It watches the place itself — Tenzy doesn't track you."))
                        .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else if nearby.looking.contains(q) {
                HStack(spacing: 6) { ProgressView(); Text(L("Finding the closest…")).font(HandyFont.caption) }
            } else {
                HStack {
                    Button { nearby.find(q) } label: { Label(L(q == "pharmacy" ? "Pharmacies near me" : "Stores near me"), systemImage: "location.fill") }.compactButton()
                    if let u = NearbyPlaces.mapsURL(q) { Link(destination: u) { Label(L("Open Maps"), systemImage: "map") }.font(HandyFont.caption) }
                }
                if nearby.denied { Text(L("Location is off — Maps will still search near you.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            }
        }
    }

    private func footer(_ p: UntanglePlan.Plan) -> some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button { addToReminders(p) } label: { Label(L("Add the plan to Reminders, with alerts"), systemImage: "checklist").frame(maxWidth: .infinity) }.primaryButton()
            Button { toggleNudges(p) } label: {
                Label(nudges ? L("Check-ins on — I'll nudge you as each step starts") : L("Nudge me as each step starts"), systemImage: nudges ? "bell.badge.fill" : "bell")
                    .frame(maxWidth: .infinity)
            }.secondaryButton()
            NotificationsOffCard(isOff: $notifOff)
            HStack(spacing: HandySpacing.s8) {
                Button { cardImage = UntanglePlanCard.image(p) } label: { Label(L("Share as a picture"), systemImage: "photo").frame(maxWidth: .infinity) }
                    .secondaryButton().accessibilityIdentifier("untangle-share-card")
                ShareLink(item: UntanglePlan.text(p)) { Label(L("Share as text"), systemImage: "text.alignleft").frame(maxWidth: .infinity) }.secondaryButton()
            }
            if let n = note { Text(L(n)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            Text(L("Made on your phone. What you type or say never leaves it — only your rough location is used for maps.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
        }
        .sheet(isPresented: Binding(get: { cardImage != nil }, set: { if !$0 { cardImage = nil } })) {
            if let img = cardImage {
                NavigationStack {
                    ScrollView {
                        Image(uiImage: img).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                            .padding(HandySpacing.gutter)
                            .accessibilityLabel(L("Your plan as a picture"))
                    }
                    .safeAreaInset(edge: .bottom) {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview(L("My plan"), image: Image(uiImage: img))) {
                            Label(L("Send or save the picture"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .primaryButton().padding(HandySpacing.gutter).background(HandyColor.bg)
                    }
                    .navigationTitle(L("Your plan as a picture")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { cardImage = nil } } }
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleArrival(_ pl: NearbyPlaces.Place, step s: UntanglePlan.Step) {
        let key = ArrivalAlert.id(pl.name, step: s.id)
        if arrivals.contains(key) { ArrivalAlert.cancel(place: pl.name, step: s.id); arrivals.remove(key); return }
        Task {
            let ok = await NotifyPermission.ensure()
            await MainActor.run {
                notifOff = !ok
                guard ok, let c = pl.item.placemark.location?.coordinate else { return }   // same source as the search
                ArrivalAlert.schedule(place: pl.name, at: c, step: s.id, task: s.title, items: s.items)
                arrivals.insert(key)
                note = "Set. When you reach \(pl.name), your list pops up."
            }
        }
    }

    private func build() {
        errorText = nil
        guard !trimmed.isEmpty else { return }
        // "life, overwhelming, money, debts" is not six 20-minute tasks. Anything that isn't a to-do list goes to
        // Think it through, which answers the worry, the decision or the question itself.
        switch ThinkBrain.kind(of: trimmed) {
        case .worry, .decision, .question, .message: plan = nil; thinkAbout = trimmed; return
        default: break
        }
        let start = Date().addingTimeInterval(TimeInterval(startIn * 60))
        var p = UntanglePlan.make(from: trimmed, detail: detail, energy: energy, start: start)
        if p.steps.isEmpty {
            errorText = "Tell me at least one thing you need to do — even a small one."
            return
        }
        // Keep progress when re-planning the same list with a different preset.
        if let old = plan {
            for i in p.steps.indices {
                if let o = old.steps.first(where: { $0.title == p.steps[i].title && $0.kind == p.steps[i].kind && !$0.isRest }) {
                    p.steps[i].id = o.id; p.steps[i].status = o.status
                }
            }
            UntanglePlan.retime(&p, from: start)
        }
        withAnimation { plan = p }
        if let q = p.steps.compactMap({ $0.kind.placeQuery }).first, nearby.places[q] == nil, !nearby.denied { nearby.find(q) }
        if nudges { UntangleCheckIns.schedule(p) }
        HandyHaptics.success()
    }

    private func update(_ change: (inout UntanglePlan.Plan) -> Void) {
        guard var p = plan else { return }
        change(&p)
        withAnimation { plan = p }
        if nudges { UntangleCheckIns.schedule(p) }
        if p.remaining.filter({ !$0.isRest }).isEmpty { note = "All done. That was a lot — well done for getting through it." }
    }

    private func toggleNudges(_ p: UntanglePlan.Plan) {
        if nudges { nudges = false; UntangleCheckIns.cancelAll(); return }
        Task {
            let ok = await NotifyPermission.ensure()
            await MainActor.run {
                nudges = true; notifOff = !ok
                UntangleCheckIns.schedule(p)     // waiting, so they arrive as soon as notifications are allowed
            }
        }
    }

    private func addToReminders(_ p: UntanglePlan.Plan) {
        let tasks = p.steps.filter { !$0.isRest && $0.status == .todo }.map { s in
            ThinkingEngine.Task(text: s.items.isEmpty ? s.title : "\(s.title): \(s.items.joined(separator: ", "))",
                                actions: ThinkingActions.plan(for: s.title), due: s.start)
        }
        Task { @MainActor in
            do {
                let n = try await ThinkingReminders.add(tasks)
                note = "Added \(n) to Reminders, each with an alert at its start time."; HandyHaptics.success()
            } catch ThinkingReminders.AddError.denied {
                errorText = "Reminders access is off. Turn it on in Settings › Tenzy and tap again."
            } catch {
                errorText = "Couldn't add to Reminders — try again."
            }
        }
    }

    private func readShot(_ item: PhotosPickerItem?) {
        guard let item else { return }
        reading = true; errorText = nil
        Task {
            var text = ""
            if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { text = await AIEngine.recognizeText(img) }
            await MainActor.run {
                reading = false; shot = nil
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errorText = "Couldn't read any text in that picture — try a clearer screenshot." }
                else { input = input.isEmpty ? text : input + "\n" + text }
            }
        }
    }

    // MARK: - Wording

    private func duration(_ m: Int) -> String { m >= 60 ? "\(m / 60)h\(m % 60 > 0 ? " \(m % 60)m" : "")" : "\(m) \(L("min"))" }

    private func timeLine(_ s: UntanglePlan.Step) -> String {
        let t = s.start.formatted(date: .omitted, time: .shortened)
        let trip = s.tripMinutes > 0 ? " (\(L("incl.")) \(s.tripMinutes) \(L("min travel")))" : ""
        return "\(t) · \(duration(s.totalMinutes))\(trip)"
    }
}

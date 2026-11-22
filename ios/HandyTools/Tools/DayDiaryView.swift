import SwiftUI
import LocalAuthentication
import UserNotifications

/// My Day — one round button. Top half red (bad day), bottom half green (good day). One tap saves the day, then a
/// short follow-up asks if you'd like to say why in a few words — record a short message, or "That's all" and done
/// (Manan, 22 Nov: "accept good or bad and then remind them if they want to record a short message… optional, or
/// else we save the information for the day and be done with it"). The day is saved on the first tap either way.
/// Review opens a colour calendar of every day you've logged, behind your diary PIN (or Face ID).
struct DayDiaryView: View {
    @StateObject private var rec = QuickRecorder()
    @State private var today: DayDiary.Day?
    @State private var recordingMood: DayDiary.Mood?
    /// Just saved: the optional "want to say why?" step is showing.
    @State private var askWhy: DayDiary.Mood?
    @State private var started: Date?
    @State private var saving = false
    @State private var thanks: String?
    @State private var showReview = false
    @State private var remind = UserDefaults.standard.bool(forKey: "daydiary.remind")
    @State private var remindAt: Date = {
        let h = UserDefaults.standard.object(forKey: "daydiary.hour") as? Int ?? 21
        let m = UserDefaults.standard.object(forKey: "daydiary.minute") as? Int ?? 0
        return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
    }()
    @State private var errorText: String?
    @State private var notifOff = false
    @State private var tick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ToolPage(title: "My Day", subtitle: "How did today go? One tap saves it — then say why if you like. Private, locked, only on your phone.", working: saving) {
            VStack(spacing: HandySpacing.s16) {
                Text(Date().formatted(date: .complete, time: .omitted)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                if let r = recordingMood { recordingCard(r) } else if let m = askWhy { followUp(m) } else { moodButton }
                if let t = thanks {
                    Label { Text(L(t)).font(HandyFont.body) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green) }
                        .cardStyle(padding: HandySpacing.s12).transition(.opacity)
                } else if let d = today {
                    Text("\(L("Today so far:")) \(d.mood == .good ? L("a good day") : L("a hard day"))\(d.notes.isEmpty ? "" : " · \(d.notes.count) \(L("voice note(s)"))")")
                        .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }

                Button { showReview = true } label: {
                    Label(L("Review my days"), systemImage: "calendar").frame(maxWidth: .infinity)
                }.secondaryButton()

                reminderCard
                Text(L("Saving a day never needs your PIN. Looking back does. Your diary is encrypted on this phone and never uploaded."))
                    .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .onAppear { today = DiaryStore.shared.day(DayDiary.key(Date())) }
        .onChange(of: rec.interrupted) { _, cut in
            // A call came in mid-recording: keep what was said before it, and say so.
            guard cut, let m = recordingMood else { return }
            stopAndSave(m)
            errorText = "A call came in, so the recording stopped. What you said before it is saved."
        }
        .onReceive(timer) { tick = $0 }
        .sheet(isPresented: $showReview) { DiaryReviewGate() }
    }

    // MARK: - The button

    private var moodButton: some View {
        let size: CGFloat = 260
        return ZStack {
            VStack(spacing: 0) {
                Button { quick(.bad) } label: {
                    ZStack(alignment: .top) {
                        Rectangle().fill(LinearGradient(colors: [Color(hex: 0xFF5A5F), Color(hex: 0xD93A3F)], startPoint: .top, endPoint: .bottom))
                        Text(L("Bad day")).font(.system(size: 22, weight: .bold)).foregroundStyle(.white).padding(.top, 48)
                    }
                }.buttonStyle(.plain).accessibilityLabel(L("Bad day"))
                Button { quick(.good) } label: {
                    ZStack(alignment: .bottom) {
                        Rectangle().fill(LinearGradient(colors: [Color(hex: 0x2FBF71), Color(hex: 0x1E9E5A)], startPoint: .top, endPoint: .bottom))
                        Text(L("Good day")).font(.system(size: 22, weight: .bold)).foregroundStyle(.white).padding(.bottom, 48)
                    }
                }.buttonStyle(.plain).accessibilityLabel(L("Good day"))
            }
            .frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 4))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)

        }
        .padding(.vertical, HandySpacing.s8)
    }

    /// Step two, optional: the day is already saved — say why in a few words, or finish here.
    private func followUp(_ mood: DayDiary.Mood) -> some View {
        let good = mood == .good
        return VStack(spacing: HandySpacing.s12) {
            Circle().fill(good ? Color(hex: 0x2FBF71) : Color(hex: 0xFF5A5F)).frame(width: 84, height: 84)
                .overlay(Image(systemName: "checkmark").font(.system(size: 34, weight: .bold)).foregroundStyle(.white))
            Text(good ? L("Saved — a good day") : L("Saved — a hard day")).font(HandyFont.title)
            Text(good ? L("Want to say what made it good? A few words is plenty — it's optional.")
                      : L("Want to say what made it hard? Getting it out can help — it's optional."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { askWhy = nil; startRecording(mood) } label: {
                Label(L("Record a short message"), systemImage: "mic.fill").frame(maxWidth: .infinity)
            }.primaryButton().accessibilityIdentifier("day-record-why")
            Button { withAnimation { askWhy = nil }; done(mood) } label: {
                Text(L("That's all — I'm done")).frame(maxWidth: .infinity)
            }.secondaryButton().accessibilityIdentifier("day-done")
            Button(good ? L("Oops — it was a hard day") : L("Oops — it was a good day")) { quick(good ? .bad : .good) }
                .textButton().font(HandyFont.caption).accessibilityIdentifier("day-flip")
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: HandySpacing.s16)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func recordingCard(_ mood: DayDiary.Mood) -> some View {
        let secs = Int(tick.timeIntervalSince(started ?? tick))
        return VStack(spacing: HandySpacing.s12) {
            Circle().fill(mood == .good ? Color(hex: 0x2FBF71) : Color(hex: 0xFF5A5F)).frame(width: 120, height: 120)
                .overlay(Image(systemName: "mic.fill").font(.system(size: 40)).foregroundStyle(.white))
                .overlay(Circle().stroke((mood == .good ? Color.green : Color.red).opacity(0.35), lineWidth: 10).scaleEffect(1.15))
            Text(mood == .good ? L("Recording — what made it good?") : L("Recording — what made it hard?")).font(HandyFont.bodyStrong)
            Text(String(format: "%d:%02d", secs / 60, secs % 60)).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
            Button { stopAndSave(mood) } label: { Label(L("Stop and save"), systemImage: "stop.circle.fill").frame(maxWidth: .infinity) }.primaryButton()
            // The day is already saved; cancelling just drops the recording.
            Button(L("Cancel")) { _ = rec.stop(); recordingMood = nil; done(mood) }.textButton()
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    // MARK: - Reminder

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Toggle(isOn: $remind) { Label(L("Ask me every evening"), systemImage: "bell.badge") }.tint(HandyColor.accent)
            if remind {
                NotificationsOffCard(isOff: $notifOff)
                DatePicker(L("At"), selection: $remindAt, displayedComponents: .hourAndMinute)
                Text(L("You can answer Good or Bad right from the notification.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }
        }
        .cardStyle(padding: HandySpacing.s12)
        .onChange(of: remind) { _, on in applyReminder(on) }
        .onChange(of: remindAt) { _, _ in if remind { applyReminder(true) } }
        .onChange(of: notifOff) { _, off in if !off, remind { applyReminder(true) } }
        .task { if remind { notifOff = await NotifyPermission.state() == .off } }
    }

    private func applyReminder(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "daydiary.remind")
        guard on else { DayDiary.cancelReminder(); return }
        let c = Calendar.current.dateComponents([.hour, .minute], from: remindAt)
        UserDefaults.standard.set(c.hour ?? 21, forKey: "daydiary.hour"); UserDefaults.standard.set(c.minute ?? 0, forKey: "daydiary.minute")
        Task {
            let ok = await NotifyPermission.ensure()
            await MainActor.run {
                notifOff = !ok
                // Scheduled either way: the moment notifications are allowed, it's already waiting.
                DayDiary.scheduleReminder(hour: c.hour ?? 21, minute: c.minute ?? 0); errorText = nil
            }
        }
    }

    // MARK: - Saving

    /// Saves the day straight away (so leaving now loses nothing), then offers the optional "say why".
    private func quick(_ mood: DayDiary.Mood) {
        guard let d = DiaryStore.shared.log(mood) else { errorText = "Couldn't save — try again."; return }
        today = d; errorText = nil; thanks = nil
        HandyHaptics.success()
        withAnimation { askWhy = mood }
    }

    private func startRecording(_ mood: DayDiary.Mood) {
        errorText = nil; thanks = nil
        recordingMood = mood; started = Date()
        rec.start { p in
            recordingMood = nil
            errorText = MicCheck.text(p, denied: "Tenzy needs the microphone to record — allow it in Settings, or just tap Good or Bad.", meanwhile: "just tap Good or Bad for now")
        }
    }

    private func stopAndSave(_ mood: DayDiary.Mood) {
        guard let file = rec.stop() else { recordingMood = nil; done(mood); return }
        let secs = Date().timeIntervalSince(started ?? Date())
        recordingMood = nil; saving = true
        Task {
            // Write it out in words too (on the phone), so the diary can be read as well as heard.
            let words = await Self.words(file)
            let stored = DiaryStore.shared.storeAudio(file)
            let note = DayDiary.Note(at: Date(), mood: mood, audio: stored, seconds: secs, transcript: words)
            await MainActor.run {
                saving = false
                guard let d = DiaryStore.shared.log(mood, note: note) else { errorText = "Couldn't save — try again."; return }
                today = d; done(mood)
            }
        }
    }

    /// The recording in words, on the phone (nil when speech isn't allowed or nothing was said).
    private static func words(_ file: URL) async -> String? {
        guard case .success(let r) = await MeetingNotes.transcribe(file, progress: { _ in }) else { return nil }
        let t = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func done(_ mood: DayDiary.Mood) {
        HandyHaptics.success()
        withAnimation { thanks = DayDiary.message(for: mood) }
    }
}

// MARK: - Review (locked)

/// Asks for the diary PIN (or Face ID), sets one up the first time, and offers recovery.
struct DiaryReviewGate: View {
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false
    @State private var pin = ""
    @State private var pin2 = ""
    @State private var question = DayDiary.questions[0]
    @State private var answer = ""
    @State private var recovering = false
    @State private var resetting = false
    @State private var errorText: String?
    private let store = DiaryStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if unlocked { DiaryCalendarView() }
                else if !store.hasPIN { setup }
                else if resetting { newPIN }
                else if recovering { recover }
                else { lock }
            }
            .navigationTitle(L(unlocked ? "My days" : "My Day is locked"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { dismiss() } } }
        }
        .onAppear { if store.hasPIN, store.useFaceID { faceID() } }
    }

    private var lock: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(HandyColor.accent)
            Text(L("Enter your diary PIN")).font(HandyFont.title)
            SecureField(L("PIN"), text: $pin).keyboardType(.numberPad).textContentType(.oneTimeCode)
                .multilineTextAlignment(.center).font(.system(size: 28, weight: .semibold)).textFieldStyle(.handy).frame(maxWidth: 220)
                .onChange(of: pin) { _, v in if v.count >= 4, store.check(pin: v) { open() } }
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
            Button(L("Unlock")) { store.check(pin: pin) ? open() : (errorText = "That's not it — try again.") }.primaryButton().disabled(pin.count < 4)
            if store.useFaceID { Button { faceID() } label: { Label(L("Use Face ID"), systemImage: "faceid") }.textButton() }
            Button(L("Forgot your PIN?")) { recovering = true; errorText = nil }.textButton().font(HandyFont.caption)
        }
        .padding(HandySpacing.gutter)
    }

    private var setup: some View {
        Form {
            Section {
                Text(L("Choose a PIN only you know. You'll need it to look back at your days — not to save them.")).font(HandyFont.caption)
                SecureField(L("New PIN (4–8 numbers)"), text: $pin).keyboardType(.numberPad)
                SecureField(L("Type it again"), text: $pin2).keyboardType(.numberPad)
            } header: { Text(L("Your diary PIN")) }
            Section {
                Picker(L("Question"), selection: $question) { ForEach(DayDiary.questions, id: \.self) { Text(L($0)).tag($0) } }
                TextField(L("Your answer"), text: $answer).autocorrectionDisabled()
                Text(L("If you forget the PIN, this answer lets you set a new one. Pick something you'll always remember and others don't know. Capitals don't matter.")).font(HandyFont.micro)
            } header: { Text(L("If you forget it")) }
            if let e = errorText { Text(L(e)).foregroundStyle(HandyColor.danger) }
            Button(L("Lock my diary")) { create() }.disabled(pin.isEmpty || answer.trimmingCharacters(in: .whitespaces).count < 2)
        }
    }

    private var recover: some View {
        Form {
            Section {
                Text(L(store.question ?? "")).font(HandyFont.bodyStrong)
                TextField(L("Your answer"), text: $answer).autocorrectionDisabled()
            } header: { Text(L("Answer your recovery question")) }
            if let e = errorText { Text(L(e)).foregroundStyle(HandyColor.danger) }
            Button(L("Check")) {
                if store.check(answer: answer) { resetting = true; recovering = false; pin = ""; pin2 = ""; errorText = nil }
                else { errorText = "That answer doesn't match. Capitals and spaces don't matter — try again." }
            }
            Button(L("Back")) { recovering = false; errorText = nil }
        }
    }

    private var newPIN: some View {
        Form {
            Section {
                SecureField(L("New PIN (4–8 numbers)"), text: $pin).keyboardType(.numberPad)
                SecureField(L("Type it again"), text: $pin2).keyboardType(.numberPad)
            } header: { Text(L("Set a new PIN")) }
            if let e = errorText { Text(L(e)).foregroundStyle(HandyColor.danger) }
            Button(L("Save new PIN")) {
                if let p = DayDiary.pinProblem(pin) { errorText = p; return }
                guard pin == pin2 else { errorText = "The two PINs don't match."; return }
                store.changePIN(pin); resetting = false; open()
            }
        }
    }

    private func create() {
        if let p = DayDiary.pinProblem(pin) { errorText = p; return }
        guard pin == pin2 else { errorText = "The two PINs don't match."; return }
        store.setPIN(pin, question: question, answer: answer)
        let ctx = LAContext()
        store.useFaceID = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        open()
    }

    private func open() { HandyHaptics.success(); withAnimation { unlocked = true } }

    private func faceID() {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Open your diary") { ok, _ in
            if ok { DispatchQueue.main.async { open() } }
        }
    }
}

/// The colour calendar: every day green or red, month by month back to the first day you logged.
struct DiaryCalendarView: View {
    @State private var month: Date = Date()
    @State private var days: [String: DayDiary.Day] = [:]
    @State private var picked: DayDiary.Day?
    private let cal = Calendar.current
    private let store = DiaryStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: HandySpacing.s12) {
                HStack {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(L("Previous month"))
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year())).font(HandyFont.title)
                    Spacer()
                    Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(cal.isDate(month, equalTo: Date(), toGranularity: .month)).accessibilityLabel(L("Next month"))
                }
                let syms = cal.veryShortStandaloneWeekdaySymbols
                let order = (0..<7).map { syms[($0 + cal.firstWeekday - 1) % 7] }
                HStack { ForEach(order.indices, id: \.self) { Text(order[$0]).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary).frame(maxWidth: .infinity) } }
                let c = cal.dateComponents([.year, .month], from: month)
                ForEach(Array(DayDiary.monthGrid(year: c.year ?? 2026, month: c.month ?? 1).enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in cell(week[i], c) }
                    }
                }
                let t = DayDiary.tally(Array(days.values))
                HStack(spacing: HandySpacing.s16) {
                    Label("\(t.good) \(L("good"))", systemImage: "circle.fill").foregroundStyle(Color(hex: 0x2FBF71))
                    Label("\(t.bad) \(L("hard"))", systemImage: "circle.fill").foregroundStyle(Color(hex: 0xFF5A5F))
                    Label("\(DayDiary.streak(store.allKeys())) \(L("days in a row"))", systemImage: "flame.fill").foregroundStyle(HandyColor.amber)
                }.font(HandyFont.caption)
            }
            .padding(HandySpacing.gutter)
        }
        .onAppear(perform: load)
        .sheet(item: Binding(get: { picked.map { DayBox(day: $0) } }, set: { picked = $0?.day })) { DiaryDayView(day: $0.day) }
    }

    private struct DayBox: Identifiable { let day: DayDiary.Day; var id: String { day.key } }

    @ViewBuilder private func cell(_ n: Int?, _ c: DateComponents) -> some View {
        if let n {
            let k = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, n)
            let d = days[k]
            Button { if let d { picked = d } } label: {
                Text("\(n)").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 42)
                    .foregroundStyle(d == nil ? HandyColor.textSecondary : .white)
                    .background(d == nil ? HandyColor.surface : (d!.mood == .good ? Color(hex: 0x2FBF71) : Color(hex: 0xFF5A5F)), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        if let d, !d.notes.isEmpty { Image(systemName: "mic.fill").font(.system(size: 8)).foregroundStyle(.white).padding(4) }
                    }
            }.buttonStyle(.plain).disabled(d == nil)
            .accessibilityLabel("\(n), \(d == nil ? L("nothing logged") : (d!.mood == .good ? L("Good day") : L("Bad day")))")
        } else { Color.clear.frame(maxWidth: .infinity, minHeight: 42) }
    }

    private func shift(_ by: Int) { if let m = cal.date(byAdding: .month, value: by, to: month) { month = m; load() } }
    private func load() { let c = cal.dateComponents([.year, .month], from: month); days = store.days(inMonthOf: c.year ?? 2026, c.month ?? 1) }
}

/// One day: good or bad, and every voice note with its words and a play button.
struct DiaryDayView: View {
    let day: DayDiary.Day
    @State private var playable: [UUID: URL] = [:]
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(day.mood == .good ? L("A good day") : L("A hard day"), systemImage: "circle.fill")
                        .foregroundStyle(day.mood == .good ? Color(hex: 0x2FBF71) : Color(hex: 0xFF5A5F)).font(HandyFont.bodyStrong)
                }
                if day.notes.isEmpty {
                    Text(L("You logged the day with one tap — no voice note.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                }
                ForEach(day.notes) { n in
                    Section(n.at.formatted(date: .omitted, time: .shortened)) {
                        if let u = playable[n.id] { AudioPlayBar(url: u) }
                        if let t = n.transcript { Text(t).font(HandyFont.body) }
                        else if n.audio != nil { Text(L("Voice note — tap play to listen.")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                    }
                }
            }
            .navigationTitle(Self.title(day.key))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            for n in day.notes { if let a = n.audio, let u = DiaryStore.shared.playable(a) { playable[n.id] = u } }
        }
        .onDisappear { for u in playable.values { try? FileManager.default.removeItem(at: u) } }
    }

    static func title(_ key: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: key) else { return key }
        return d.formatted(date: .complete, time: .omitted)
    }
}

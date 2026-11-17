import Foundation
import EventKit

/// The one-tap "Act on it" writer for the thinking tools: it drops a result's tasks straight into the
/// system Reminders app. The OS permission prompt on first use is the single confirm the person was
/// promised — after they allow it, every later add is silent and one-tap. The field mapping (what each
/// reminder's title, due date and note should be) is pure and unit-tested off-device; only the save
/// touches EventKit. It never dead-ends: a denied permission is reported honestly with a route to fix it,
/// and the dated steps are still there to add to Calendar.
enum ThinkingReminders {
    /// What one task becomes as a reminder — pure, so the mapping is tested without a device.
    struct Field: Equatable {
        let title: String
        let due: Date?
        let notes: String?
    }

    /// Map a task to its reminder fields: a tidy title, its due date if any, and a note naming the place.
    static func field(for task: ThinkingEngine.Task) -> Field {
        let trimmed = task.text.trimmingCharacters(in: .whitespaces)
        let title = trimmed.isEmpty ? trimmed : trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        let notes = task.actions.place.map { "At \($0)" }
        return Field(title: title, due: task.due, notes: notes)
    }

    static func fields(for tasks: [ThinkingEngine.Task]) -> [Field] { tasks.map(field(for:)) }

    enum AddError: Error { case denied, noList, failed }

    /// Add every task as a reminder. Requests access once (the OS prompt); throws `.denied` if the person
    /// says no, so the UI can point them to Settings rather than failing silently. Dated tasks get a due
    /// date and an alarm so the reminder actually nudges at the right time.
    @MainActor static func add(_ tasks: [ThinkingEngine.Task], store: EKEventStore = EKEventStore()) async throws -> Int {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .reminder)) ?? false
        }
        guard granted else { throw AddError.denied }
        guard let cal = store.defaultCalendarForNewReminders() else { throw AddError.noList }

        var added = 0
        for f in fields(for: tasks) where !f.title.isEmpty {
            let r = EKReminder(eventStore: store)
            r.calendar = cal
            r.title = f.title
            if let notes = f.notes { r.notes = notes }
            if let due = f.due {
                r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
                r.addAlarm(EKAlarm(absoluteDate: due))
            }
            try store.save(r, commit: false)
            added += 1
        }
        try store.commit()
        return added
    }
}

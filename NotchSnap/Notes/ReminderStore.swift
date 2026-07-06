import Foundation
import EventKit
import SwiftUI

// MARK: - ReminderStore — EventKit bridge for the Notes tab
//
// Reminders are the one thing that is NOT local JSON: they live in Apple's
// EventKit store so they sync natively with the Reminders app (and every
// other device) — no shadow todo list.
//
// IMPORTANT: views never bind to EKReminder objects directly — they don't
// publish changes. Fetched reminders are snapshotted into `upcoming`
// (a lightweight value wrapper) and re-fetched after every mutation.

struct UpcomingReminder: Identifiable, Equatable {
    let id: String            // calendarItemIdentifier
    let title: String
    let dueDate: Date?
    let isOverdue: Bool
    var isCompleted: Bool
}

@MainActor
final class ReminderStore: ObservableObject {
    static let shared = ReminderStore()

    enum AccessState {
        case undetermined, granted, denied
    }

    @Published private(set) var access: AccessState = .undetermined
    @Published private(set) var upcoming: [UpcomingReminder] = []

    private let eventStore = EKEventStore()
    private let listName = "NotchSnap"    // fixed for v1

    private init() {
        refreshAccessState()
    }

    private func refreshAccessState() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:                      access = .granted
            case .denied, .restricted, .writeOnly: access = .denied
            default:                               access = .undetermined
            }
        } else {
            switch status {
            case .authorized:          access = .granted
            case .denied, .restricted: access = .denied
            default:                   access = .undetermined
            }
        }
    }

    // MARK: - Access

    /// Ask for Reminders access (system dialog on first call). Returns granted.
    func requestAccess() async -> Bool {
        if access == .granted { return true }
        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            granted = (try? await eventStore.requestAccess(to: .reminder)) ?? false
        }
        access = granted ? .granted : .denied
        if granted { await refresh() }
        return granted
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - NotchSnap list (create-if-missing)

    private func ensureDefaultList() -> EKCalendar? {
        let calendars = eventStore.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == listName }) {
            return existing
        }
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = listName
        calendar.source = eventStore.defaultCalendarForNewReminders()?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .local })
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print("[Reminders] Could not create list: \(error)")
            return eventStore.defaultCalendarForNewReminders()
        }
    }

    // MARK: - Create / complete / refresh

    /// Create a reminder in the NotchSnap list. Returns its identifier.
    @discardableResult
    func createReminder(title: String, due: Date?) async -> String? {
        guard await requestAccess() else { return nil }
        guard let calendar = ensureDefaultList() else { return nil }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar
        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        do {
            try eventStore.save(reminder, commit: true)
            await refresh()
            return reminder.calendarItemIdentifier
        } catch {
            print("[Reminders] Save failed: \(error)")
            return nil
        }
    }

    func toggleComplete(_ id: String) async {
        guard access == .granted,
              let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = !reminder.isCompleted
        try? eventStore.save(reminder, commit: true)
        HapticManager.shared.thumbnailSelect()
        await refresh()
    }

    /// Snapshot incomplete reminders due today or overdue (plus recently
    /// completed ones so the strikethrough moment is visible).
    func refresh() async {
        guard access == .granted else { return }
        let calendars = eventStore.calendars(for: .reminder)
            .filter { $0.title == listName }
        guard !calendars.isEmpty else {
            upcoming = []
            return
        }

        let predicate = eventStore.predicateForReminders(in: calendars)
        // EKReminder isn't Sendable — snapshot into value types INSIDE the
        // fetch callback so only plain values cross back to the main actor.
        let snapshot: [UpcomingReminder] = await withCheckedContinuation { cont in
            eventStore.fetchReminders(matching: predicate) { result in
                let endOfTomorrow = Calendar.current.startOfDay(for: Date())
                    .addingTimeInterval(2 * 86400)
                let items = (result ?? [])
                    .filter { reminder in
                        if reminder.isCompleted { return false }
                        guard let comps = reminder.dueDateComponents,
                              let due = Calendar.current.date(from: comps) else {
                            return true   // undated reminders stay visible
                        }
                        return due < endOfTomorrow   // today, overdue, tomorrow
                    }
                    .map { reminder -> UpcomingReminder in
                        let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                        return UpcomingReminder(
                            id: reminder.calendarItemIdentifier,
                            title: reminder.title ?? "",
                            dueDate: due,
                            isOverdue: due.map { $0 < Date() } ?? false,
                            isCompleted: reminder.isCompleted
                        )
                    }
                    .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                cont.resume(returning: items)
            }
        }

        upcoming = snapshot
    }
}

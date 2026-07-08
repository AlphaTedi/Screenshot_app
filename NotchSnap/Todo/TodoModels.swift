import Foundation
import SwiftUI

// MARK: - Todo models
//
// NotchSnap's own lightweight to-do system. This is DELIBERATELY distinct
// from the EventKit-backed reminders in ReminderStore: a TodoItem is local,
// collection-scoped, and never touches Apple Reminders. The two coexist —
// the Notes composer still promotes to EKReminder; to-dos are their own
// keyboard-first system.

enum TodoUrgency: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:    return L10n.t("urgency.low")
        case .medium: return L10n.t("urgency.medium")
        case .high:   return L10n.t("urgency.high")
        }
    }

    /// TD-7: secondary to the collection colour — a small dot, never an accent
    /// competing with the collection's identity.
    var color: Color {
        switch self {
        case .low:    return Color(red: 0.60, green: 0.85, blue: 0.55)
        case .medium: return Color(red: 1.00, green: 0.75, blue: 0.30)
        case .high:   return Color(red: 1.00, green: 0.35, blue: 0.35)
        }
    }

    /// KB-4: cycle order, wrapping back to low.
    var next: TodoUrgency {
        switch self {
        case .low:    return .medium
        case .medium: return .high
        case .high:   return .low
        }
    }
}

struct TodoCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var shortcutKey: String?
    /// TD-8: true only for the built-in smart Today aggregation. Today is a
    /// live query across every collection, not a membership bucket.
    var isSystemToday: Bool = false

    var color: Color {
        Color(nsColor: NSColor.fromHex(colorHex) ?? .systemBlue)
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var collectionID: UUID
    var urgency: TodoUrgency = .low
    var isCompleted: Bool = false
    var completedAt: Date?
    var dueDate: Date?
    var sortOrder: Int
    let createdAt: Date
}

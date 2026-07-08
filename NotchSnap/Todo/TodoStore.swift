import Foundation
import SwiftUI

// MARK: - TodoStore — source of truth for collections + to-dos
//
// Persistence reuses the app's established pattern (one JSON file in
// Application Support, debounced writes) — same as ShelfStore/NotesStore.

@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var collections: [TodoCollection] = []
    @Published private(set) var items: [TodoItem] = []

    /// The collection currently being browsed. `nil` never happens after init.
    @Published var activeCollectionID: UUID?
    /// Persisted across quick-entry invocations (KB-3: category defaults to
    /// the last-used collection).
    @Published var lastUsedCollectionID: UUID?
    /// TD-3: Completed is collapsed by default.
    @Published var completedExpanded = false
    /// KB-6: keyboard focus within the browsing list.
    @Published var focusedItemID: UUID?

    private var saveWork: Task<Void, Never>?

    // MARK: - Storage

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("NotchSnap/Todo", isDirectory: true)
    }
    private var fileURL: URL { Self.directory.appendingPathComponent("todos.json") }

    private struct Payload: Codable {
        var collections: [TodoCollection]
        var items: [TodoItem]
        var lastUsedCollectionID: UUID?
    }

    private init() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        load()
        if collections.isEmpty { seedStarterCollections() }
        activeCollectionID = collections.first?.id
        lastUsedCollectionID = lastUsedCollectionID ?? firstUserCollection?.id
    }

    /// TD-1: a starter set, fully renameable/deletable.
    private func seedStarterCollections() {
        collections = [
            TodoCollection(id: UUID(), name: "Today", colorHex: "#FFCC00",
                           sortOrder: 0, shortcutKey: "1", isSystemToday: true),
            TodoCollection(id: UUID(), name: "Work", colorHex: "#5AC8FA",
                           sortOrder: 1, shortcutKey: "2"),
            TodoCollection(id: UUID(), name: "Personal", colorHex: "#C79AF0",
                           sortOrder: 2, shortcutKey: "3"),
        ]
        scheduleSave()
    }

    // MARK: - Derived

    var firstUserCollection: TodoCollection? {
        collections.first { !$0.isSystemToday }
    }

    var activeCollection: TodoCollection? {
        collections.first { $0.id == activeCollectionID } ?? collections.first
    }

    func collection(id: UUID) -> TodoCollection? {
        collections.first { $0.id == id }
    }

    /// TD-8: Today is a live smart aggregation — anything due today (or
    /// overdue) or flagged High urgency, pulled from every collection.
    /// Every other collection is a plain membership query.
    func openItems(in collection: TodoCollection) -> [TodoItem] {
        let base: [TodoItem]
        if collection.isSystemToday {
            let endOfToday = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
            base = items.filter { item in
                guard !item.isCompleted else { return false }
                if item.urgency == .high { return true }
                if let due = item.dueDate, due < endOfToday { return true }
                return false
            }
        } else {
            base = items.filter { !$0.isCompleted && $0.collectionID == collection.id }
        }
        return base.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// TD-3: grouping resolved as "by completion date, most recent first".
    var completedItems: [TodoItem] {
        items.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// VW-2: how many rows the panel must make room for right now.
    var visibleRowCount: Int {
        let open = activeCollection.map { openItems(in: $0).count } ?? 0
        let completed = completedExpanded ? completedItems.count : 0
        return open + completed + 1   // +1 for the Completed header row
    }

    // MARK: - Collections

    @discardableResult
    func addCollection(name: String, colorHex: String) -> TodoCollection {
        let next = (collections.map(\.sortOrder).max() ?? -1) + 1
        let shortcut = next < 9 ? String(next + 1) : nil
        let collection = TodoCollection(
            id: UUID(), name: name, colorHex: colorHex,
            sortOrder: next, shortcutKey: shortcut
        )
        withAnimation(NotchAnimation.newScreenshot) { collections.append(collection) }
        scheduleSave()
        return collection
    }

    func deleteCollection(_ id: UUID) {
        guard let victim = collection(id: id), !victim.isSystemToday else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            collections.removeAll { $0.id == id }
            items.removeAll { $0.collectionID == id }
        }
        if activeCollectionID == id { activeCollectionID = collections.first?.id }
        if lastUsedCollectionID == id { lastUsedCollectionID = firstUserCollection?.id }
        scheduleSave()
    }

    /// KB-8: ⌘1…⌘9 select by tab order.
    func selectCollection(atIndex index: Int) {
        let ordered = collections.sorted { $0.sortOrder < $1.sortOrder }
        guard index >= 0, index < ordered.count else { return }
        withAnimation(NotchAnimation.expand) {
            activeCollectionID = ordered[index].id
        }
        focusedItemID = nil
    }

    func selectCollection(_ id: UUID) {
        withAnimation(NotchAnimation.expand) { activeCollectionID = id }
        focusedItemID = nil
    }

    // MARK: - Items

    @discardableResult
    func addItem(title: String, collectionID: UUID, urgency: TodoUrgency) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Today is a smart view, never a home — file into the last real
        // collection instead so the item is never stranded (KB-5 fallback).
        var target = collectionID
        if collection(id: target)?.isSystemToday ?? true {
            target = firstUserCollection?.id ?? collectionID
        }

        let next = (items.filter { $0.collectionID == target }.map(\.sortOrder).max() ?? -1) + 1
        let item = TodoItem(
            id: UUID(), title: trimmed, collectionID: target,
            urgency: urgency, isCompleted: false, completedAt: nil,
            dueDate: nil, sortOrder: next, createdAt: Date()
        )
        withAnimation(NotchAnimation.newScreenshot) { items.append(item) }
        lastUsedCollectionID = target
        // Step 5 of the capture flow: the created to-do's collection becomes
        // the active tab, so it's visibly filed where the user put it.
        activeCollectionID = target
        HapticManager.shared.copyConfirmed()
        scheduleSave()
        return item
    }

    /// TD-4/TD-5: completing files into Completed; un-completing restores it
    /// to its original collection (collectionID was never cleared).
    func toggleComplete(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            items[idx].isCompleted.toggle()
            items[idx].completedAt = items[idx].isCompleted ? Date() : nil
        }
        HapticManager.shared.thumbnailSelect()
        scheduleSave()
    }

    func setUrgency(_ urgency: TodoUrgency, for id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            items[idx].urgency = urgency
        }
        scheduleSave()
    }

    /// KB-9: reassign an existing to-do to another collection.
    func move(_ id: UUID, toCollection collectionID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }),
              let target = collection(id: collectionID), !target.isSystemToday else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            items[idx].collectionID = collectionID
        }
        scheduleSave()
    }

    func delete(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.removeAll { $0.id == id }
        }
        HapticManager.shared.itemDeleted()
        scheduleSave()
    }

    /// TD-11: keyboard-accessible reorder within a collection.
    func moveItem(_ id: UUID, by offset: Int) {
        guard let collection = activeCollection, !collection.isSystemToday else { return }
        var ordered = openItems(in: collection)
        guard let from = ordered.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard to >= 0, to < ordered.count else { return }
        ordered.swapAt(from, to)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            for (i, item) in ordered.enumerated() {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].sortOrder = i
                }
            }
        }
        scheduleSave()
    }

    // MARK: - Keyboard focus (KB-6)

    func moveFocus(_ offset: Int) {
        guard let collection = activeCollection else { return }
        let rows = openItems(in: collection)
        guard !rows.isEmpty else { focusedItemID = nil; return }
        guard let current = focusedItemID,
              let idx = rows.firstIndex(where: { $0.id == current }) else {
            focusedItemID = rows.first?.id
            return
        }
        let next = max(0, min(rows.count - 1, idx + offset))
        focusedItemID = rows[next].id
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        collections = payload.collections.sorted { $0.sortOrder < $1.sortOrder }
        items = payload.items
        lastUsedCollectionID = payload.lastUsedCollectionID
    }

    private func scheduleSave() {
        saveWork?.cancel()
        saveWork = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            let payload = Payload(
                collections: self.collections,
                items: self.items,
                lastUsedCollectionID: self.lastUsedCollectionID
            )
            if let data = try? JSONEncoder().encode(payload) {
                try? data.write(to: self.fileURL)
            }
        }
    }
}

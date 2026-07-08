import SwiftUI
import AppKit

// MARK: - TodoBrowsingView — the to-do half of the Notes tab
//
// Layout law (PRD §2.2), enforced here and worth keeping:
//   • Strict single column, everything left-aligned to one margin. Only
//     trailing count badges / urgency dots sit at the right edge.
//   • Exactly one collection visible at a time — switching tabs REPLACES
//     the list; collections are never mixed. Today is the one exception,
//     because cross-collection aggregation is its entire purpose.
//   • Tabs (not combo boxes) switch collections while browsing. Combo boxes
//     belong to the creation flow only.

// MARK: - TodoTabView — the To-do tab (own tab, own shortcut ⌃⇧T)

struct TodoTabView: View {
    var body: some View {
        TodoBrowsingView()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(TodoBrowsingKeyHandler())
    }
}

struct TodoBrowsingView: View {
    @ObservedObject private var store = TodoStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            collectionTabs
            hairline
            todoList
            hairline
            completedSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hairline: some View {
        Rectangle().fill(Color.white.opacity(0.09)).frame(height: 0.5)
    }

    // MARK: - Collection tabs (TD-9)

    private var collectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.collections) { collection in
                    CollectionTab(
                        collection: collection,
                        isActive: collection.id == store.activeCollectionID
                    ) {
                        store.selectCollection(collection.id)
                    }
                }

                Button {
                    TodoCollectionEditor.shared.show()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)
                .help(L10n.t("todo.newCollection"))

                Spacer(minLength: 4)

                // KB-10: shortcuts are only useful if people can find them.
                Button {
                    TodoShortcutsOverlay.shared.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)
                .help(L10n.t("todo.shortcuts") + "  \u{2318}/")
            }
        }
    }

    // MARK: - Open to-dos (one collection at a time)

    @ViewBuilder
    private var todoList: some View {
        if let collection = store.activeCollection {
            let rows = store.openItems(in: collection)
            if rows.isEmpty {
                Text(collection.isSystemToday ? L10n.t("todo.emptyToday") : L10n.t("todo.empty"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(rows) { item in
                            TodoRow(
                                item: item,
                                accent: store.collection(id: item.collectionID)?.color ?? .accentColor,
                                isFocused: store.focusedItemID == item.id
                            )
                        }
                    }
                }
                // VW-3: beyond the cap the list scrolls internally rather
                // than growing the panel further.
                .frame(maxHeight: 240)
            }
        }
    }

    // MARK: - Completed (TD-3) — collapsed by default, by completion date

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(NotchAnimation.expand) { store.completedExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: store.completedExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                    Text(L10n.t("todo.completed"))
                        .font(.system(size: 11, weight: .medium))
                    Text("\(store.completedItems.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.completedExpanded {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(store.completedItems) { item in
                            TodoRow(
                                item: item,
                                accent: store.collection(id: item.collectionID)?.color ?? .gray,
                                isFocused: false
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - CollectionTab (TD-9: colour ONLY when active)

private struct CollectionTab: View {
    let collection: TodoCollection
    let isActive: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(collection.name)
                .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                // Colour reads as an ACTIVE-STATE signal, never a permanent
                // badge: inactive tabs stay neutral whatever colour they own.
                .foregroundStyle(isActive ? Color.black.opacity(0.93)
                                          : Color.white.opacity(hover ? 0.75 : 0.53))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? collection.color
                                       : Color.white.opacity(hover ? 0.08 : 0.0))
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isActive)
        .contextMenu {
            if !collection.isSystemToday {
                Button(L10n.t("action.delete"), role: .destructive) {
                    TodoStore.shared.deleteCollection(collection.id)
                }
            }
        }
    }
}

// MARK: - TodoRow (TD-10)

private struct TodoRow: View {
    let item: TodoItem
    let accent: Color
    let isFocused: Bool
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                TodoStore.shared.toggleComplete(item.id)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(accent, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if item.isCompleted {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(accent)
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // TD-4: the fill lands with a satisfying spring.
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: item.isCompleted)

            Text(item.title)
                .font(.system(size: 13))
                .strikethrough(item.isCompleted)
                .foregroundStyle(.white.opacity(item.isCompleted ? 0.35 : 0.9))
                .lineLimit(1)

            Spacer(minLength: 6)

            // TD-10: urgency shows only when it isn't the Low default,
            // and stays visually secondary to the collection colour.
            if item.urgency != .low && !item.isCompleted {
                Circle()
                    .fill(item.urgency.color)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.12)
                                : (hover ? Color.white.opacity(0.06) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isFocused ? accent.opacity(0.7) : .clear, lineWidth: 1)
        )
        .onHover { hover = $0 }
        .contextMenu {
            ForEach(TodoUrgency.allCases) { u in
                Button(u.label) { TodoStore.shared.setUrgency(u, for: item.id) }
            }
            Divider()
            Button(L10n.t("todo.moveTo")) { TodoMovePicker.shared.show(itemID: item.id) }
            Divider()
            Button(L10n.t("action.delete"), role: .destructive) {
                TodoStore.shared.delete(item.id)
            }
        }
    }
}

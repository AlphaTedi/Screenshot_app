import SwiftUI
import AppKit

// MARK: - TodoTabView — the whole to-do panel (design PRD §§1-7)
//
// One surface, four modes (TodoPanelMode): browsing and creation share the
// tab row; category creation and Quick Find replace the content entirely.
// All colors/spacing/radii/fonts come from DesignSystem.swift (DSColor,
// DSSpacing, DSRadius, DSFont) and its reusable components — never inline
// hex values (design PRD §11, drift table §10).
//
// Content sits directly on the notch's black — single background, only
// element-level fills (Marcello's explicit call, 2026-07-13; it overrides
// the #111 panel shown in the PRD §1 markup).
//
// Layout law (pivot PRD §3): fixed width, VARIABLE height. This view
// measures its natural height and publishes it; the notch shape animates to
// match on NotchAnimation.contentHug (the exact response 0.45 / damping 0.60
// spring the PRD §8.2 mandates — DSAnimation.primary is a rough conversion
// of the same spring and its own comment says to prefer tuned values).

// MARK: - Height measurement

private struct TodoContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SectionHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// UG-2 tooltip plumbing: the hovered/focused row's dot reports its anchor;
/// TodoTabView renders the bubble at PANEL level so the list ScrollView's
/// clipping can't cut it off (for the first row it floats over the tabs).
private struct UrgencyTooltipInfo {
    let text: String
    let anchor: Anchor<CGRect>
}

private struct UrgencyTooltipKey: PreferenceKey {
    static let defaultValue: [UrgencyTooltipInfo] = []
    static func reduce(value: inout [UrgencyTooltipInfo],
                       nextValue: () -> [UrgencyTooltipInfo]) {
        value.append(contentsOf: nextValue())
    }
}

private extension View {
    func measureHeight<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: key, value: proxy.size.height)
            }
        )
    }
}

// MARK: - TodoTabView

struct TodoTabView: View {
    @ObservedObject private var store = TodoStore.shared

    private var modeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        )
    }

    var body: some View {
        // §2.3: the shortcuts overlay sits ON TOP of the live content —
        // dismissing is instant, nothing re-renders underneath.
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                // The tab row lives OUTSIDE the mode switch: its identity is
                // stable across browsing ↔ create, so toggling "+" swaps only
                // the content below — same motion as switching categories.
                if store.panelMode == .browsing || store.panelMode == .create {
                    TodoTabRow()
                }
                // ZStack, not bare switch: during a transition BOTH the
                // outgoing and incoming views exist for a few frames — as
                // VStack siblings they'd stack vertically and the whole
                // panel visibly jumped (Marcello's Work→Today report).
                // Overlapped, the swap reads as one in-place motion.
                ZStack(alignment: .topLeading) {
                    switch store.panelMode {
                    case .browsing:
                        TodoBrowsingView()
                            .transition(modeTransition)
                    case .create:
                        TodoCreateView()
                            .transition(modeTransition)
                    case .newCategory:
                        CategoryFormView()
                            .transition(modeTransition)
                    case .find:
                        QuickFindView()
                            .transition(modeTransition)
                    }
                }
            }

            if store.showShortcuts {
                ShortcutsOverlay()
                    .transition(.opacity)
            }
        }
        .padding(EdgeInsets(top: 14, leading: DSSpacing.panelPadding,
                            bottom: DSSpacing.panelPadding, trailing: DSSpacing.panelPadding))
        // UG-2: immediate tooltip near the hovered/focused row's urgency dot,
        // clamped so it can't overflow the panel's edges.
        .overlayPreferenceValue(UrgencyTooltipKey.self) { infos in
            GeometryReader { geo in
                if let info = infos.first {
                    let rect = geo[info.anchor]
                    UrgencyTooltip(text: info.text)
                        .position(x: min(max(rect.midX, 46), geo.size.width - 46),
                                  y: rect.minY - 18)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .animation(NotchAnimation.hintFade, value: infos.first?.text)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // Hugging height: the notch shape is a direct animated function of
        // this measurement.
        .measureHeight(TodoContentHeightKey.self)
        .onPreferenceChange(TodoContentHeightKey.self) { height in
            AppState.shared.todoContentHeight = height
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TodoBrowsingKeyHandler())
    }
}

// MARK: - Tab row — CreationTabChip + CategoryTabChips (design PRD §3.1)
//
// Drift table §10: a tab is label + optional ring, NOTHING else (#4); the
// "+" tab is the only creation entry point (#5); badges exist only while ⌘
// is held (#2); the active tab wears its own category color at regular
// weight (#1). New-category creation lives in the tabs' context menu.

private struct TodoTabRow: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var modifiers = ModifierMonitor.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    if store.panelMode == .create {
                        store.setMode(.browsing)
                    } else {
                        store.presetDraftToActiveCollection()
                        store.setMode(.create)
                        NotchController.shared.focusPanel()
                    }
                } label: {
                    CreationTabChip(isActive: store.panelMode == .create)
                        .contentShape(RoundedRectangle(cornerRadius: DSRadius.chipCorner))
                }
                .buttonStyle(.plain)
                .help(L10n.t("todo.newTodo"))

                ForEach(Array(store.collections.enumerated()), id: \.element.id) { index, collection in
                    Button {
                        store.selectCollection(collection.id)
                    } label: {
                        CategoryTabChip(
                            title: collection.name,
                            categoryColor: collection.color,
                            isActive: store.panelMode == .browsing
                                && collection.id == store.activeCollectionID,
                            progress: store.progress(for: collection),
                            numberBadge: (modifiers.commandHeld && index < 9) ? index + 1 : nil
                        )
                        .contentShape(RoundedRectangle(cornerRadius: DSRadius.chipCorner))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.t("todo.newCollection") + "\u{2026}") {
                            store.setMode(.newCategory)
                            NotchController.shared.focusPanel()
                        }
                        Divider()
                        Button(L10n.t("action.moveLeft")) {
                            store.moveCollection(collection.id, by: -1)
                        }
                        .disabled(index == 0)
                        Button(L10n.t("action.moveRight")) {
                            store.moveCollection(collection.id, by: 1)
                        }
                        .disabled(index == store.collections.count - 1)
                        if !collection.isSystemToday {
                            Divider()
                            Button(L10n.t("action.delete"), role: .destructive) {
                                store.deleteCollection(collection.id)
                            }
                        }
                    }
                }
            }
            // Headroom so the ⌘-held badges (offset y:-8) render inside the
            // scroll container instead of being clipped.
            .padding(.top, 8)
        }
        .padding(.bottom, DSSpacing.tabRowBottomPadding)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DSColor.dividerSubtle).frame(height: 0.5)
        }
        .padding(.bottom, DSSpacing.tabRowBottomMargin)
    }
}

// MARK: - TodoBrowsingView — the list + Completed (browsing mode content)

struct TodoBrowsingView: View {
    @ObservedObject private var store = TodoStore.shared

    private static let listCap: CGFloat = 300
    private static let completedCap: CGFloat = 120
    /// Small lists render at natural height with NO ScrollView and no
    /// measurement round-trip. The measured-scroll path lags one layout pass
    /// behind, and on category switches that lag made the incoming list
    /// start short and visibly expand — worst on the largest category
    /// ("Personal slides in from the top", Marcello 2026-07-15).
    private static let inlineRowThreshold = 10
    private static let inlineCompletedThreshold = 4

    @State private var listNaturalHeight: CGFloat = 0
    @State private var completedNaturalHeight: CGFloat = 0
    @State private var draggedItemID: UUID?

    var body: some View {
        // §8.3 category switch: the id() swap transitions the whole block
        // while the panel height animates — content and container together.
        if let collection = store.activeCollection {
            // Same jump guard as the mode switch: the id() swap keeps two
            // copies alive mid-transition; overlap them instead of stacking.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    todoList(for: collection)
                    completedSection(for: collection)
                }
                .id(collection.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                ))
            }
        }
    }

    // MARK: Open list

    @ViewBuilder
    private func todoList(for collection: TodoCollection) -> some View {
        let rows = store.openItems(in: collection)
        if rows.isEmpty {
            Text(collection.isSystemToday ? L10n.t("todo.emptyToday") : L10n.t("todo.empty"))
                .font(DSFont.checklistItem)
                .foregroundStyle(DSColor.textHint)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if rows.count <= Self.inlineRowThreshold {
            // Natural height, zero lag — the panel hugs it directly.
            openRows(rows, in: collection)
        } else {
            ScrollView(showsIndicators: false) {
                openRows(rows, in: collection)
                    .measureHeight(SectionHeightKey.self)
            }
            .onPreferenceChange(SectionHeightKey.self) { listNaturalHeight = $0 }
            .frame(height: min(listNaturalHeight, Self.listCap))
        }
    }

    private func openRows(_ rows: [TodoItem], in collection: TodoCollection) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.rowInternalGap) {
            ForEach(rows) { item in
                TodoItemRow(
                    item: item,
                    accent: store.collection(id: item.collectionID)?.color ?? .accentColor,
                    isFocused: store.focusedItemID == item.id,
                    isExpanded: store.expandedItemID == item.id
                )
                .transition(rowTransition)
                .onDrag {
                    if !collection.isSystemToday { draggedItemID = item.id }
                    return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: TodoReorderDropDelegate(
                    targetID: item.id,
                    draggedID: $draggedItemID,
                    enabled: !collection.isSystemToday
                ))
            }
        }
    }

    private var rowTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity.combined(with: .offset(x: 24))
        )
    }

    // MARK: Completed (TD-3, per-category)

    @ViewBuilder
    private func completedSection(for collection: TodoCollection) -> some View {
        let completed = store.completedItems(in: collection)
        if !completed.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Rectangle().fill(DSColor.divider).frame(height: 0.5)
                    .padding(.top, DSSpacing.tabRowBottomMargin)

                Button {
                    withAnimation(NotchAnimation.contentHug) { store.completedExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DSColor.textFaint)
                            .rotationEffect(.degrees(store.completedExpanded ? 90 : 0))
                        Text(L10n.t("todo.completed"))
                            .font(DSFont.checklistItem)
                            .foregroundStyle(DSColor.textMuted)
                        Text("\(completed.count)")
                            .font(.system(size: 10))
                            .foregroundStyle(DSColor.textHint)
                            .contentTransition(.numericText())
                        Spacer()
                    }
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if store.completedExpanded {
                    if completed.count <= Self.inlineCompletedThreshold {
                        completedRows(completed)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        ScrollView(showsIndicators: false) {
                            completedRows(completed)
                                .measureHeight(SectionHeightKey.self)
                        }
                        .onPreferenceChange(SectionHeightKey.self) { completedNaturalHeight = $0 }
                        .frame(height: min(completedNaturalHeight, Self.completedCap))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private func completedRows(_ completed: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(completed) { item in
                TodoItemRow(
                    item: item,
                    accent: store.collection(id: item.collectionID)?.color ?? .gray,
                    isFocused: false,
                    isExpanded: false
                )
                .transition(rowTransition)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Drag-to-reorder (TD-5)

private struct TodoReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    let enabled: Bool

    func dropEntered(info: DropInfo) {
        guard enabled, let dragged = draggedID, dragged != targetID else { return }
        TodoStore.shared.reorder(dragged, before: targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: enabled ? .move : .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return enabled
    }
}

// MARK: - TodoItemRow — live row (collapsed + NC expanded states)
//
// DesignSystem.swift's `TodoRow` is the static visual reference for this
// row's collapsed look; the live app row additionally needs completion
// state, urgency dot, the NC-2 details indicator, and the expanded
// note/checklist editor — so this view exists, styled EXCLUSIVELY from the
// same DS tokens so the two can't drift apart.

private struct TodoItemRow: View {
    let item: TodoItem
    let accent: Color
    let isFocused: Bool
    let isExpanded: Bool
    @State private var hover = false
    @State private var newStep = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow

            if isExpanded {
                expandedDetails
            }
        }
        .padding(.horizontal, isExpanded ? 12 : 8)
        .padding(.vertical, isExpanded ? 10 : 7)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.controlCorner, style: .continuous)
                .fill(isExpanded ? DSColor.fieldBackground
                                 : (isFocused ? DSColor.focusedRowBackground
                                              : (hover ? Color.white.opacity(0.04) : .clear)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.controlCorner, style: .continuous)
                .stroke((isFocused || isExpanded) ? DSColor.focusAccent : .clear, lineWidth: 0.5)
        )
        .animation(NotchAnimation.hintFade, value: isFocused)
        .onHover { hover = $0 }
        .contextMenu { contextMenuItems }
    }

    private var titleRow: some View {
        HStack(spacing: DSSpacing.rowInternalGap) {
            Button {
                TodoStore.shared.toggleComplete(item.id)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.checkboxCorner, style: .continuous)
                        .strokeBorder(accent, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if item.isCompleted {
                        RoundedRectangle(cornerRadius: DSRadius.checkboxCorner, style: .continuous)
                            .fill(accent)
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(DSColor.primaryText.opacity(0.8))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // §8.3: near-instant fill; row exit + shrink follow on contentHug.
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: item.isCompleted)

            if item.isCompleted {
                Text(item.title)
                    .font(DSFont.todoTitle)
                    .strikethrough(true)
                    .foregroundStyle(DSColor.textHint)
                    .lineLimit(1)
            } else {
                // EH-1..6: links/dates/mentions/code render as inline chips
                // in the flowing, wrapping title.
                EntityTitleView(
                    title: item.title,
                    isBright: isFocused || isExpanded,
                    onTap: activateRow
                )
            }

            Spacer(minLength: 6)

            // NC-2: collapsed rows with details wear a subtle indicator.
            if item.hasDetails && !isExpanded {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 8))
                    .foregroundStyle(DSColor.textHint)
            }

            // UG-1/UG-5: 9px dot, Medium/High only — Low (the default)
            // stays visually silent, so a dot always means "raised".
            if item.urgency != .low && !item.isCompleted {
                UrgencyDot(urgency: item.urgency)
                    .anchorPreference(key: UrgencyTooltipKey.self, value: .bounds) { anchor in
                        (hover || isFocused)
                            ? [UrgencyTooltipInfo(text: item.urgency.fullLabel, anchor: anchor)]
                            : []
                    }
            }

            // §7.1: only the focused row shows its one relevant shortcut.
            if isFocused && !item.isCompleted && !isExpanded {
                ShortcutHintBadge(text: "\u{21A9}")
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: activateRow)
    }

    /// NC-1: deliberate open — clicking the row body (not the checkbox)
    /// toggles the note/checklist details. Non-link clicks inside the
    /// entity title view route here too.
    private func activateRow() {
        let store = TodoStore.shared
        store.focusedItemID = item.id
        guard !item.isCompleted else { return }
        withAnimation(NotchAnimation.contentHug) {
            store.expandedItemID = (store.expandedItemID == item.id) ? nil : item.id
        }
    }

    // MARK: NC expanded details — note with left rule, sub-checklist (§7)

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(DSColor.panelBorder)
                    .frame(width: 0.5)
                    .padding(.leading, 6)
                TextField(L10n.t("todo.notePlaceholder"),
                          text: noteBinding, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DSFont.checklistItem)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1...4)
                    .padding(.leading, 17)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(item.checklist) { step in
                    HStack(spacing: 6) {
                        Button {
                            TodoStore.shared.toggleChecklistItem(step.id, in: item.id)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: DSRadius.checklistCheckboxCorner,
                                                 style: .continuous)
                                    .strokeBorder(DSColor.textFaint, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                if step.isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 6, weight: .bold))
                                        .foregroundStyle(DSColor.textSecondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text(step.title)
                            .font(DSFont.checklistItem)
                            .strikethrough(step.isDone)
                            .foregroundStyle(step.isDone ? DSColor.textFaint : Color(hex: "#AAAAAA"))
                        Spacer(minLength: 0)
                    }
                    .contextMenu {
                        Button(L10n.t("action.delete"), role: .destructive) {
                            TodoStore.shared.deleteChecklistItem(step.id, in: item.id)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 7))
                        .foregroundStyle(DSColor.textHint)
                        .frame(width: 10, height: 10)
                    TextField(L10n.t("todo.addStep"), text: $newStep)
                        .textFieldStyle(.plain)
                        .font(DSFont.checklistItem)
                        .foregroundStyle(Color(hex: "#AAAAAA"))
                        .onSubmit {
                            TodoStore.shared.addChecklistItem(newStep, to: item.id)
                            newStep = ""
                        }
                }
            }
            .padding(.leading, DSSpacing.checklistIndent)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
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

    private var noteBinding: Binding<String> {
        Binding(
            get: { TodoStore.shared.items.first { $0.id == item.id }?.note ?? "" },
            set: { TodoStore.shared.setNote($0, for: item.id) }
        )
    }
}

// MARK: - ShortcutsOverlay — in-panel `?` reference (§2.3)

private struct ShortcutsOverlay: View {
    private let rows: [(String, String)] = [
        ("\u{2191} \u{2193}", "todo.sc.moveFocus"),
        ("\u{21A9}", "todo.sc.toggleComplete"),
        ("\u{2192} \u{2190}", "todo.sc.expandRow"),
        ("\u{2318}N", "todo.sc.newTodo"),
        ("\u{2318}1\u{2013}9 / \u{2318}", "todo.sc.switchCollection"),
        ("\u{2325}\u{2191}\u{2193}", "todo.sc.reorder"),
        ("\u{21E7}\u{2318}M", "todo.sc.moveItem"),
        ("a\u{2026}z", "todo.sc.quickFind"),
        ("\u{2325}\u{2318}N", "todo.sc.quickEntry"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(L10n.t("todo.shortcuts").uppercased())
                    .font(DSFont.sectionLabel)
                    .tracking(0.4)
                    .foregroundStyle(DSColor.textMuted)
                Spacer()
                Text(L10n.t("todo.sc.closeHint"))
                    .font(.system(size: 10))
                    .foregroundStyle(DSColor.textHint)
            }
            .padding(.bottom, 4)

            ForEach(rows, id: \.0) { keys, labelKey in
                HStack {
                    Text(L10n.t(labelKey))
                        .font(DSFont.checklistItem)
                        .foregroundStyle(Color(hex: "#CCCCCC"))
                    Spacer()
                    ShortcutHintBadge(text: keys)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#0A0A0A").opacity(0.94))
        )
    }
}

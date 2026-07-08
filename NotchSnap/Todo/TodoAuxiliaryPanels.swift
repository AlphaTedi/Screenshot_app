import AppKit
import SwiftUI

// MARK: - Shared floating-panel helper for the small to-do dialogs

@MainActor
private func presentPanel<Content: View>(
    size: NSSize,
    store: inout NSPanel?,
    @ViewBuilder content: () -> Content
) {
    store?.orderOut(nil)
    guard let screen = NSScreen.main else { return }
    let frame = NSRect(
        x: screen.frame.midX - size.width / 2,
        y: screen.frame.midY - size.height / 2 + 60,
        width: size.width, height: size.height
    )
    let panel = QuickEntryPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered, defer: false
    )
    panel.level = .floating
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true

    let host = NSHostingView(rootView: content())
    host.frame = NSRect(origin: .zero, size: size)
    host.autoresizingMask = [.width, .height]
    host.wantsLayer = true
    host.layer?.cornerRadius = 14
    host.layer?.cornerCurve = .continuous
    host.layer?.masksToBounds = true
    panel.contentView = host

    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    store = panel
}

// MARK: - TodoCollectionEditor — create a collection (TD-1: user name + colour)

@MainActor
final class TodoCollectionEditor {
    static let shared = TodoCollectionEditor()
    private var panel: NSPanel?

    func show() {
        presentPanel(size: NSSize(width: 320, height: 220), store: &panel) {
            CollectionEditorView { [weak self] in self?.close() }
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct CollectionEditorView: View {
    @State private var name = ""
    @State private var colorHex = "#5AC8FA"
    @FocusState private var nameFocused: Bool
    let onDone: () -> Void

    private static let palette = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#5AC8FA", "#007AFF", "#C79AF0", "#FF6482",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("todo.newCollection").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))

            TextField(L10n.t("todo.collectionName"), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused($nameFocused)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(nameFocused ? Color.accentColor : Color.white.opacity(0.12), lineWidth: 1)
                )
                .onSubmit(create)

            HStack(spacing: 8) {
                ForEach(Self.palette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(nsColor: NSColor.fromHex(hex) ?? .systemBlue))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(L10n.t("snippet.cancel")) { onDone() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.t("snippet.create"), action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FrostedGlassBackground().ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { nameFocused = true }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        TodoStore.shared.addCollection(name: trimmed, colorHex: colorHex)
        onDone()
    }
}

// MARK: - TodoMovePicker — KB-9, ⇧⌘M type-ahead reassignment

@MainActor
final class TodoMovePicker {
    static let shared = TodoMovePicker()
    private var panel: NSPanel?

    func show(itemID: UUID) {
        presentPanel(size: NSSize(width: 320, height: 260), store: &panel) {
            MovePickerView(itemID: itemID) { [weak self] in self?.close() }
        }
    }

    /// ⇧⌘M with no explicit item: operate on the focused row.
    func showForFocusedItem() {
        guard let id = TodoStore.shared.focusedItemID else { return }
        show(itemID: id)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct MovePickerView: View {
    @ObservedObject private var store = TodoStore.shared
    let itemID: UUID
    let onDone: () -> Void

    @State private var query = ""
    @FocusState private var queryFocused: Bool

    /// Type-ahead beats scrolling (Things 3's Move dialog).
    private var matches: [TodoCollection] {
        let assignable = store.collections.filter { !$0.isSystemToday }
        guard !query.isEmpty else { return assignable }
        return assignable.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("todo.moveTo").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))

            TextField(L10n.t("todo.searchCollections"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused($queryFocused)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .onSubmit { commit(matches.first) }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(matches) { c in
                        Button { commit(c) } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(c.color)
                                    .frame(width: 12, height: 12)
                                Text(c.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FrostedGlassBackground().ignoresSafeArea())
        .onExitCommand { onDone() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { queryFocused = true }
        }
    }

    private func commit(_ collection: TodoCollection?) {
        guard let collection else { return }
        store.move(itemID, toCollection: collection.id)
        onDone()
    }
}

// MARK: - TodoShortcutsOverlay — KB-10 discoverability ("?" in the tab)

@MainActor
final class TodoShortcutsOverlay {
    static let shared = TodoShortcutsOverlay()
    private var panel: NSPanel?

    func toggle() {
        if panel != nil { close(); return }
        presentPanel(size: NSSize(width: 360, height: 320), store: &panel) {
            ShortcutsOverlayView { [weak self] in self?.close() }
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ShortcutsOverlayView: View {
    let onDone: () -> Void

    private let rows: [(String, String)] = [
        ("\u{2325}Space", "todo.sc.quickEntry"),
        ("\u{2318}N", "todo.sc.newTodo"),
        ("\u{2318}1\u{2013}9", "todo.sc.switchCollection"),
        ("\u{2191}\u{2193}", "todo.sc.moveFocus"),
        ("Space", "todo.sc.toggleComplete"),
        ("\u{2318}\u{21E7}M", "todo.sc.moveItem"),
        ("\u{2318}\u{21E5}", "todo.sc.cycleCollection"),
        ("\u{2318}\u{21E7}\u{21E5}", "todo.sc.cycleUrgency"),
        ("\u{21A9}", "todo.sc.create"),
        ("Esc", "todo.sc.cancel"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("todo.shortcuts").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.0) { keys, key in
                    HStack(spacing: 12) {
                        Text(keys)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 74, alignment: .leading)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        Text(L10n.t(key))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FrostedGlassBackground().ignoresSafeArea())
        .onExitCommand { onDone() }
    }
}

import AppKit
import SwiftUI

// MARK: - TodoQuickEntry — the creation flow (PRD §4.2)
//
// Creation is its OWN self-contained screen, never inline in the browsing
// list. Strict step order, always:
//   1. Type      — title field, focused the instant the window opens.
//   2. Category  — combo box, defaults to last-used collection.
//   3. Urgency   — combo box, defaults to Low.
//   4. Send      — explicit Create (Return). No auto-commit, ever.
//   5. File      — the to-do lands in its collection, which becomes active.
//
// Combo boxes are closed by default and cycle via shortcut without opening,
// so the screen stays compact no matter how many collections exist. This
// pattern is scoped to creation — browsing switches collections via tabs.

@MainActor
final class TodoQuickEntryController {
    static let shared = TodoQuickEntryController()

    private var panel: NSPanel?
    /// KB-11: a title typed then escaped survives as a draft.
    private var draftTitle = ""

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() { isVisible ? close(commit: false) : show() }

    func show() {
        if isVisible { return }

        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 380, height: 300)
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

        let host = NSHostingView(rootView: TodoQuickEntryView(
            initialTitle: draftTitle,
            onCancel: { [weak self] title in
                self?.draftTitle = title   // KB-11 safety net
                self?.close(commit: false)
            },
            onCreated: { [weak self] in
                self?.draftTitle = ""
                self?.close(commit: true)
            }
        ))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        host.wantsLayer = true
        host.layer?.cornerRadius = 16
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        panel.contentView = host

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close(commit: Bool) {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// Borderless panels can't become key by default — the title field needs it.
final class QuickEntryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - The creation screen

private struct TodoQuickEntryView: View {
    @ObservedObject private var store = TodoStore.shared

    @State private var title: String
    @State private var collectionID: UUID?
    @State private var urgency: TodoUrgency = .low
    @FocusState private var titleFocused: Bool

    let onCancel: (String) -> Void
    let onCreated: () -> Void

    init(initialTitle: String, onCancel: @escaping (String) -> Void, onCreated: @escaping () -> Void) {
        _title = State(initialValue: initialTitle)
        self.onCancel = onCancel
        self.onCreated = onCreated
    }

    private var selectedCollection: TodoCollection? {
        store.collections.first { $0.id == collectionID }
    }

    /// Collections you can actually file into — Today is a smart view.
    private var assignable: [TodoCollection] {
        store.collections.filter { !$0.isSystemToday }
    }

    var body: some View {
        // Single column, left-aligned, generous vertical rhythm: each step
        // is its own labelled block (PRD §2.2 "lean into vertical space").
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("todo.newTodo").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)

            // STEP 1 — Type
            TextField(L10n.t("todo.titlePlaceholder"), text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($titleFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(titleFocused ? Color.accentColor : Color.white.opacity(0.12),
                                lineWidth: 1)
                )
                .onSubmit(create)

            // STEP 2 — Category (combo box, closed by default)
            ComboRow(
                swatch: selectedCollection?.color ?? .gray,
                label: selectedCollection?.name ?? L10n.t("todo.noCollection"),
                keys: "\u{2318}\u{21E5}",
                menu: {
                    ForEach(assignable) { c in
                        Button(c.name) { collectionID = c.id }
                    }
                }
            )

            // STEP 3 — Urgency (combo box, defaults Low)
            ComboRow(
                swatch: urgency.color,
                label: urgency.label,
                keys: "\u{2318}\u{21E7}\u{21E5}",
                menu: {
                    ForEach(TodoUrgency.allCases) { u in
                        Button(u.label) { urgency = u }
                    }
                }
            )

            // STEP 4 — Send (explicit, never implicit)
            Button(action: create) {
                HStack(spacing: 8) {
                    Text(L10n.t("todo.create"))
                        .font(.system(size: 14, weight: .semibold))
                    Text("\u{21A9}")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.black.opacity(0.12))
                        )
                }
                .foregroundStyle(canCreate ? .black : .black.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(canCreate ? Color.white.opacity(0.92) : Color.white.opacity(0.25))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FrostedGlassBackground().ignoresSafeArea())
        // Cycle shortcuts fire without opening either combo box (KB-3/KB-4).
        .background(
            QuickEntryKeyHandler(
                onCycleCollection: cycleCollection,
                onCycleUrgency: { urgency = urgency.next },
                onCreate: create,
                onCancel: { onCancel(title) }
            )
        )
        .onAppear {
            collectionID = store.lastUsedCollectionID ?? assignable.first?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { titleFocused = true }
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && collectionID != nil
    }

    private func cycleCollection() {
        guard !assignable.isEmpty else { return }
        let idx = assignable.firstIndex { $0.id == collectionID } ?? -1
        collectionID = assignable[(idx + 1) % assignable.count].id
    }

    private func create() {
        guard canCreate, let cid = collectionID else { return }
        store.addItem(title: title, collectionID: cid, urgency: urgency)
        onCreated()
    }
}

// MARK: - ComboRow — closed-by-default picker with a visible shortcut

private struct ComboRow<MenuContent: View>: View {
    let swatch: Color
    let label: String
    let keys: String
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(swatch)
                    .frame(width: 14, height: 14)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Text(keys)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Key handling for the creation flow
//
// A local monitor rather than .keyboardShortcut: ⌘⇥ is swallowed by the
// system before SwiftUI sees it, and we need Escape to route the typed
// title back out as a draft (KB-11).

private struct QuickEntryKeyHandler: NSViewRepresentable {
    let onCycleCollection: () -> Void
    let onCycleUrgency: () -> Void
    let onCreate: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(
            onCycleCollection: onCycleCollection,
            onCycleUrgency: onCycleUrgency,
            onCreate: onCreate,
            onCancel: onCancel
        )
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.install(
            onCycleCollection: onCycleCollection,
            onCycleUrgency: onCycleUrgency,
            onCreate: onCreate,
            onCancel: onCancel
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitor: Any?
        private var cycleCollection: (() -> Void)?
        private var cycleUrgency: (() -> Void)?
        private var create: (() -> Void)?
        private var cancel: (() -> Void)?

        func install(onCycleCollection: @escaping () -> Void,
                     onCycleUrgency: @escaping () -> Void,
                     onCreate: @escaping () -> Void,
                     onCancel: @escaping () -> Void) {
            cycleCollection = onCycleCollection
            cycleUrgency = onCycleUrgency
            create = onCreate
            cancel = onCancel
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let cmd = event.modifierFlags.contains(.command)
                let shift = event.modifierFlags.contains(.shift)

                if event.keyCode == 53 {                 // escape
                    self.cancel?(); return nil
                }
                if event.keyCode == 36 {                 // return
                    self.create?(); return nil
                }
                if cmd, event.keyCode == 48 {            // tab
                    shift ? self.cycleUrgency?() : self.cycleCollection?()
                    return nil
                }
                return event
            }
        }

        func remove() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { remove() }
    }
}

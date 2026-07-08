import AppKit
import SwiftUI

// MARK: - TodoBrowsingKeyHandler — keyboard-first browsing (KB-6..KB-9)
//
// A local key monitor rather than SwiftUI .keyboardShortcut: the notch is a
// non-activating panel whose rows aren't in the responder chain, and ⌘⇥ /
// bare arrow keys never reach SwiftUI shortcut handlers reliably. Only
// active while the Notes tab is on screen and no modal to-do panel is up.

struct TodoBrowsingKeyHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // NSEvent isn't Sendable — snapshot the fields we need before
                // hopping onto the actor, and pass plain values across.
                let cmd = event.modifierFlags.contains(.command)
                let shift = event.modifierFlags.contains(.shift)
                let option = event.modifierFlags.contains(.option)
                let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
                let keyCode = event.keyCode
                let consumed = MainActor.assumeIsolated {
                    Self.handle(cmd: cmd, shift: shift, option: option,
                                chars: chars, keyCode: keyCode)
                }
                return consumed ? nil : event
            }
        }

        /// Returns true if the event was consumed.
        @MainActor
        private static func handle(cmd: Bool, shift: Bool, option: Bool,
                                   chars: String, keyCode: UInt16) -> Bool {
            // The quick-entry window owns the keyboard while it's up.
            guard !TodoQuickEntryController.shared.isVisible else { return false }
            // Don't steal keys while the user is typing in the note composer.
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                // ⌘N still opens quick entry even from a text field.
                if cmd, chars == "n" {
                    TodoQuickEntryController.shared.show()
                    return true
                }
                return false
            }

            let store = TodoStore.shared

            // KB-7: ⌘N opens the creation flow from inside the app.
            if cmd, !shift, chars == "n" {
                TodoQuickEntryController.shared.show()
                return true
            }

            // KB-9: ⇧⌘M moves the focused to-do to another collection.
            if cmd, shift, chars == "m" {
                TodoMovePicker.shared.showForFocusedItem()
                return true
            }

            // KB-10: ⌘/ reveals every shortcut.
            if cmd, chars == "/" {
                TodoShortcutsOverlay.shared.toggle()
                return true
            }

            // KB-8: ⌘1…⌘9 select a collection by tab order.
            if cmd, let digit = Int(chars), (1...9).contains(digit) {
                store.selectCollection(atIndex: digit - 1)
                return true
            }

            // TD-11: ⌥↑/⌥↓ reorder the focused to-do.
            if option, keyCode == 126 || keyCode == 125,
               let focused = store.focusedItemID {
                store.moveItem(focused, by: keyCode == 126 ? -1 : 1)
                return true
            }

            // KB-6: arrows move focus, Space/Return toggle completion.
            switch keyCode {
            case 126:                       // up
                store.moveFocus(-1); return true
            case 125:                       // down
                store.moveFocus(1); return true
            case 49, 36:                    // space, return
                guard let focused = store.focusedItemID else { return false }
                store.toggleComplete(focused)
                return true
            default:
                return false
            }
        }

        func remove() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { remove() }
    }
}

import AppKit
import SwiftUI

// MARK: - SettingsWindowController
//
// Custom NSWindow that hosts SettingsView. Replaces SwiftUI's `Settings { }`
// scene so we get full control over the chrome:
//   • borderless-feeling window with traffic-light buttons floating top-left
//   • no native title bar / toolbar strip
//   • a single, generous rounded-corner mask (no AppKit-managed outer corners
//     fighting our inner content mask)
//   • frosted-glass background bleeds straight to the screen edge

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private static var sharedController: SettingsWindowController?

    static func show() {
        if sharedController == nil {
            sharedController = SettingsWindowController()
        }
        guard let controller = sharedController else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.center()
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Strip every bit of native title-bar chrome.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none

        // Transparent so our SwiftUI frosted-glass background reaches the edge.
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true

        // Kill the subtle blur the system draws in the titlebar region (the
        // horizontal seam right under the traffic lights). We walk up to the
        // titlebar container view and clear its layer background so it
        // becomes truly transparent — letting our single FrostedGlassBackground
        // bleed all the way to the top edge.
        if let closeButton = window.standardWindowButton(.closeButton),
           let titlebarContainer = closeButton.superview?.superview {
            titlebarContainer.wantsLayer = true
            titlebarContainer.layer?.backgroundColor = NSColor.clear.cgColor
            // Walk further up to catch the NSThemeFrame's titlebar visual
            // effect view, which on some macOS versions sits one level higher.
            for sibling in titlebarContainer.subviews {
                sibling.wantsLayer = true
                if String(describing: type(of: sibling)).contains("VisualEffect") {
                    sibling.isHidden = true
                }
            }
        }

        // Keep the traffic-light buttons visible — only chrome we want.
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        self.init(window: window)
        window.delegate = self

        // Host SettingsView and apply a single rounded-corner mask to the
        // whole content view. Because the window background is clear and the
        // title bar is transparent, this is the ONLY rounded rect on screen —
        // no more "two corner radii" effect.
        let host = NSHostingView(
            rootView: SettingsView().environmentObject(AppState.shared)
        )
        host.frame = NSRect(x: 0, y: 0, width: 880, height: 620)
        host.autoresizingMask = [.width, .height]
        host.wantsLayer = true
        host.layer?.cornerRadius = 22
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true

        window.contentView = host
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
            // Drop the controller so the next open is a fresh window.
            SettingsWindowController.sharedController = nil
        }
    }
}

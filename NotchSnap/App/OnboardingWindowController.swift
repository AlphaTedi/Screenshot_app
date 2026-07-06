import AppKit
import SwiftUI

// MARK: - OnboardingWindowController — NSWindow (not NSPanel) for stable onboarding

class OnboardingWindowController: NSWindowController {

    private static var sharedController: OnboardingWindowController?

    static func show() {
        if sharedController == nil {
            sharedController = OnboardingWindowController()
        }
        // The app may be running as an accessory (no Dock icon) — become a
        // regular app first, or the window can silently stay behind others
        // on a fresh install.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        sharedController?.showWindow(nil)
        sharedController?.window?.center()
        sharedController?.window?.makeKeyAndOrderFront(nil)
        sharedController?.window?.orderFrontRegardless()
    }

    static func dismiss() {
        sharedController?.window?.close()
        sharedController = nil
        // Return to menu-bar-only mode if the user keeps the Dock icon off.
        Task { @MainActor in
            if !AppState.shared.settings.showInDock {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 540),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.center()

        // Hide traffic lights
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        self.init(window: window)

        let hostingView = NSHostingView(rootView: OnboardingFlowView())
        window.contentView = hostingView
    }
}

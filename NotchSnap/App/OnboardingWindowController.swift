import AppKit
import SwiftUI

// MARK: - OnboardingWindowController — NSWindow (not NSPanel) for stable onboarding

class OnboardingWindowController: NSWindowController {

    private static var sharedController: OnboardingWindowController?

    static func show() {
        if sharedController == nil {
            sharedController = OnboardingWindowController()
        }
        sharedController?.showWindow(nil)
        sharedController?.window?.center()
        sharedController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        sharedController?.window?.close()
        sharedController = nil
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

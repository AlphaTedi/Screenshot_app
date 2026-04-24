import Foundation
import AppKit
import SwiftUI

// MARK: - Editor Window Controller

@MainActor
class EditorWindowController {
    static let shared = EditorWindowController()

    private var window: NSPanel?
    private var currentItemID: UUID?
    private var localKeyMonitor: Any?
    private var currentEditorState: EditorState?

    func open(item: ScreenshotItem) {
        // Close existing editor if open
        close()

        let mousePos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mousePos, $0.frame, false)
        }) ?? NSScreen.main else { return }

        // Calculate window size (fit image, max 72% screen — reduced to avoid notch area)
        let maxWidth = screen.visibleFrame.width * 0.72
        let maxHeight = screen.visibleFrame.height * 0.72
        let imgWidth = CGFloat(item.originalImage.width)
        let imgHeight = CGFloat(item.originalImage.height)
        let scale = min(maxWidth / imgWidth, maxHeight / imgHeight, 1.0)

        let windowWidth = imgWidth * scale + 40  // padding
        let windowHeight = imgHeight * scale + 100 // toolbar + bottom bar + padding
        let windowX = screen.visibleFrame.midX - windowWidth / 2
        // Position lower on screen (8% from bottom) to stay away from notch
        let windowY = screen.visibleFrame.minY + screen.visibleFrame.height * 0.08

        let rect = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .utilityWindow

        let editorState = EditorState(item: item)
        let editorView = EditorView(editorState: editorState, onClose: { [weak self] in
            self?.close()
        })
        .frame(width: windowWidth, height: windowHeight)

        let hostingView = NSHostingView(rootView: editorView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        // Add drag handle in bottom-right corner for repositioning
        let dragHandle = DragHandleView(frame: NSRect(x: windowWidth - 28, y: 4, width: 24, height: 24))
        dragHandle.autoresizingMask = [.minXMargin, .maxYMargin]
        hostingView.addSubview(dragHandle)

        // Animate in
        panel.alphaValue = 0
        panel.setFrame(rect.insetBy(dx: 10, dy: 10), display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(rect, display: true)
        }

        self.window = panel
        self.currentItemID = item.id
        self.currentEditorState = editorState
        AppState.shared.selectedScreenshotID = item.id

        // Local key monitor for Cmd+C, Cmd+S, Esc (since nonactivatingPanel
        // doesn't support SwiftUI .keyboardShortcut)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window != nil else { return event }
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "c":
                    self.currentEditorState?.copyToClipboard()
                    return nil
                case "s":
                    self.currentEditorState?.saveToFile()
                    return nil
                default: break
                }
            }
            if event.keyCode == 53 { // Esc
                self.close()
                return nil
            }
            return event
        }
    }

    func close() {
        guard let window = window else { return }

        // Auto-copy on close if there are annotations
        if let itemID = currentItemID,
           let item = AppState.shared.screenshots.first(where: { $0.id == itemID }),
           item.hasAnnotations && AppState.shared.settings.autoCopyToClipboard {
            AppState.shared.copyToClipboard(item)
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })

        // Remove key monitor
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }

        self.window = nil
        self.currentItemID = nil
        self.currentEditorState = nil
        AppState.shared.selectedScreenshotID = nil
    }
}

// MARK: - Drag Handle (for repositioning the editor window)

class DragHandleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let text = "⠿" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attrs)
        let x = (bounds.width - size.width) / 2
        let y = (bounds.height - size.height) / 2
        text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

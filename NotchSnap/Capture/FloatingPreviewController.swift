import AppKit
import SwiftUI

// MARK: - FloatingPreviewController — CleanShot-style corner preview
//
// After a quick capture (⌃⇧4 and friends — NOT the editor flow), a small
// draggable thumbnail slides in at the bottom-left of the screen:
//   • drag it straight into any app (native file drag, instant)
//   • hover to reveal Copy / dismiss actions — hovering pauses auto-dismiss
//   • click to open the editor
//   • auto-dismisses after a few seconds
// The notch stays the management center; this is just the transient
// "here's what you captured, grab it" affordance.

@MainActor
final class FloatingPreviewController {
    static let shared = FloatingPreviewController()

    private var panel: NSPanel?
    private var dismissWork: Task<Void, Never>?

    // Layout
    private let margin: CGFloat = 20
    private let maxThumbWidth: CGFloat = 224
    private let maxThumbHeight: CGFloat = 148
    private let actionBarHeight: CGFloat = 0   // actions overlay the image

    func show(item: ScreenshotItem) {
        close(animated: false)

        guard let screen = NSScreen.main else { return }

        // Aspect-fit the thumbnail into the max box.
        let imgSize = item.thumbnail.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }
        let scale = min(maxThumbWidth / imgSize.width, maxThumbHeight / imgSize.height, 1.0)
        let size = NSSize(width: max(120, imgSize.width * scale),
                          height: max(80, imgSize.height * scale))

        let origin = NSPoint(
            x: screen.visibleFrame.minX + margin,
            y: screen.visibleFrame.minY + margin
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false

        let host = NSHostingView(rootView: FloatingPreviewView(
            item: item,
            onHoverChanged: { [weak self] hovering in
                if hovering {
                    self?.cancelAutoDismiss()
                } else {
                    self?.scheduleAutoDismiss(seconds: 2.5)
                }
            },
            onCopy: { [weak self] in
                AppState.shared.copyToClipboard(item)
                self?.close(animated: true)
            },
            onDismiss: { [weak self] in
                self?.close(animated: true)
            },
            onOpenEditor: { [weak self] in
                self?.close(animated: false)
                EditorWindowController.shared.open(item: item)
            }
        ))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        // Slide in from the left edge with a spring-ish ease.
        let finalFrame = panel.frame
        var startFrame = finalFrame
        startFrame.origin.x = screen.visibleFrame.minX - size.width - 40
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        scheduleAutoDismiss(seconds: 6)
    }

    // MARK: - Auto-dismiss

    private func scheduleAutoDismiss(seconds: Double) {
        cancelAutoDismiss()
        dismissWork = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.close(animated: true)
        }
    }

    private func cancelAutoDismiss() {
        dismissWork?.cancel()
        dismissWork = nil
    }

    // MARK: - Close

    func close(animated: Bool) {
        cancelAutoDismiss()
        guard let panel else { return }
        self.panel = nil

        if animated, let screen = NSScreen.main {
            var outFrame = panel.frame
            outFrame.origin.x = screen.visibleFrame.minX - outFrame.width - 40
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(outFrame, display: true)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }
}

// MARK: - FloatingPreviewView — SwiftUI body of the corner preview

private struct FloatingPreviewView: View {
    let item: ScreenshotItem
    let onHoverChanged: (Bool) -> Void
    let onCopy: () -> Void
    let onDismiss: () -> Void
    let onOpenEditor: () -> Void

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Native draggable thumbnail — drag straight to Finder/apps.
            DraggableThumbnail(item: item, onTap: onOpenEditor)

            // Hover action bar
            if hovering {
                HStack(spacing: 8) {
                    PreviewActionButton(
                        icon: copied ? "checkmark" : "doc.on.doc",
                        label: copied ? "Copied" : "Copy",
                        tint: copied ? .green : .white
                    ) {
                        copied = true
                        HapticManager.shared.copyConfirmed()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            onCopy()
                        }
                    }

                    Spacer()

                    PreviewActionButton(icon: "xmark", label: nil, tint: .white) {
                        onDismiss()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hovering)
        .onHover { h in
            hovering = h
            onHoverChanged(h)
        }
    }
}

private struct PreviewActionButton: View {
    let icon: String
    let label: String?
    let tint: Color
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(hover ? 0.25 : 0.15))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

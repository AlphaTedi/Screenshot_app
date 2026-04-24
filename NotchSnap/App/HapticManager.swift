import AppKit

// MARK: - HapticManager — Centralized trackpad haptic + sound feedback
//
// Every user-facing event maps to a specific haptic pattern + sound.
// Gracefully degrades on Macs without Force Touch trackpad.

final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()
    private let performer = NSHapticFeedbackManager.defaultPerformer

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticFeedback")
    }

    // MARK: - Notch Events

    /// Notch expands: transition to gallery visible
    func notchExpanded() {
        guard isEnabled else { return }
        // Single tap (like hover) — `.levelChange` produced a double-pulse
        // that felt "laggy / continuous".
        performer.perform(.generic, performanceTime: .now)
        SoundManager.shared.play(.expand)
    }

    /// Notch collapses: gallery hidden
    func notchCollapsed() {
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
        SoundManager.shared.play(.collapse)
    }

    /// Hover enters notch zone: light single tap, NO sound (too frequent)
    func notchHoverEntered() {
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
    }

    // Legacy aliases
    func hoverTap() { notchHoverEntered() }
    func expandTap() { notchExpanded() }

    // MARK: - Screenshot Events

    /// Screenshot captured: primary action
    func screenshotCaptured() {
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
        SoundManager.shared.play(.capture)
    }

    func captureFeedback() { screenshotCaptured() }

    // MARK: - Clipboard & Actions

    /// Copy confirmed: double tap for "doppio click" feeling
    func copyConfirmed() {
        guard isEnabled else { return }
        performer.perform(.alignment, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.performer.perform(.alignment, performanceTime: .now)
        }
        SoundManager.shared.play(.copy)
    }

    /// New clipboard item added (passive event — very light)
    func clipboardItemAdded() {
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
        SoundManager.shared.play(.clipboard)
    }

    /// Thumbnail selected (tap)
    func thumbnailSelect() {
        guard isEnabled else { return }
        performer.perform(.alignment, performanceTime: .now)
    }

    func thumbnailSelected() { thumbnailSelect() }

    // MARK: - Drag & Drop

    func dragBegan() {
        guard isEnabled else { return }
        performer.perform(.levelChange, performanceTime: .now)
    }

    func dropCompleted() {
        guard isEnabled else { return }
        performer.perform(.alignment, performanceTime: .drawCompleted)
    }

    // MARK: - Delete

    func itemDeleted() {
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
        SoundManager.shared.play(.delete)
    }
}

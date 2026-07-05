import AppKit

// MARK: - HapticManager — Centralized trackpad haptic + sound feedback
//
// Every user-facing event maps to a specific haptic pattern + sound.
// Gracefully degrades on Macs without Force Touch trackpad.
//
// Sounds are dispatched BEFORE the haptic guard: the "hapticFeedback"
// toggle only controls trackpad taps, while sounds obey their own
// "soundEffectsEnabled" toggle (checked inside SoundManager).

final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()
    private let performer = NSHapticFeedbackManager.defaultPerformer

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticFeedback")
    }

    // MARK: - Notch Events

    /// Notch expands: transition to gallery visible
    func notchExpanded() {
        SoundManager.shared.play(.expand)
        guard isEnabled else { return }
        // Single tap (like hover) — `.levelChange` produced a double-pulse
        // that felt "laggy / continuous".
        performer.perform(.generic, performanceTime: .now)
    }

    /// Notch collapses: gallery hidden
    func notchCollapsed() {
        SoundManager.shared.play(.collapse)
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
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
        SoundManager.shared.play(.capture)
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
    }

    func captureFeedback() { screenshotCaptured() }

    // MARK: - Clipboard & Actions

    /// Copy confirmed: double tap for "doppio click" feeling
    func copyConfirmed() {
        SoundManager.shared.play(.copy)
        guard isEnabled else { return }
        performer.perform(.alignment, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.performer.perform(.alignment, performanceTime: .now)
        }
    }

    /// New clipboard item added (passive event — very light)
    func clipboardItemAdded() {
        SoundManager.shared.play(.clipboard)
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
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
        SoundManager.shared.play(.delete)
        guard isEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
    }
}

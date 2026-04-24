import AppKit
import UniformTypeIdentifiers

// MARK: - ClipboardMonitor — Observe pasteboard changes in real-time
//
// NSPasteboard has no notification API — polling changeCount at 0.5s is the standard approach.
// Used by Maccy, Pasta, and other clipboard managers.

@MainActor
class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var skipNext: Bool = false

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Call this before programmatically writing to the pasteboard (e.g., Quick Copy)
    /// so the monitor doesn't add a duplicate item.
    func skipNextChange() {
        skipNext = true
    }

    private func checkForChanges() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if skipNext {
            skipNext = false
            return
        }

        // Classify and add to gallery
        if let item = ClipboardItem.fromPasteboard(pb) {
            AppState.shared.addClipboardItem(item)
            NotchController.shared.triggerClipboardNotification(item: item)
        }
    }
}

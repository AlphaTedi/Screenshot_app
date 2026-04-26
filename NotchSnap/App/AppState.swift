import Foundation
import AppKit
import SwiftUI

// MARK: - QuickLookItem — Hovered gallery item for Spacebar Quick Look
//
// Defined here (rather than in QuickLookPreview.swift) so AppState can
// reference it without depending on file target-membership ordering.

enum QuickLookItem: Equatable {
    case screenshot(ScreenshotItem)
    case clipboard(ClipboardItem)

    var trackingID: UUID {
        switch self {
        case .screenshot(let s): return s.id
        case .clipboard(let c):  return c.id
        }
    }

    static func == (lhs: QuickLookItem, rhs: QuickLookItem) -> Bool {
        lhs.trackingID == rhs.trackingID
    }
}

// MARK: - AppState — Source of truth

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var screenshots: [ScreenshotItem] = []
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var isNotchExpanded: Bool = false
    @Published var selectedScreenshotID: UUID? = nil
    @Published var settings: AppSettings = AppSettings.load()
    @Published var lastCaptureMode: CaptureMode = .area

    /// Currently-hovered gallery item — drives the Spacebar Quick Look preview.
    /// Set by ScreenshotThumbnailView and ClipboardTile in their .onHover.
    @Published var hoveredQuickLookItem: QuickLookItem? = nil

    private let maxClipboardItems = 30

    // MARK: - Screenshot Management

    func addScreenshot(_ item: ScreenshotItem) {
        // 1. Insert immediately — UI updates instantly
        screenshots.insert(item, at: 0)

        // FIFO removal
        if screenshots.count > settings.maxSessionScreenshots {
            let removed = screenshots.removeLast()
            TempFileManager.shared.cleanupFile(for: removed.id)
        }

        // 2. Haptic + sound feedback (non-blocking)
        HapticManager.shared.screenshotCaptured()

        // 3. Everything else happens in background — ZERO main thread blocking
        let itemID = item.id
        let originalImage = item.originalImage
        let autoCopy = settings.autoCopyToClipboard
        let autoSave = settings.autoSaveFile

        Task.detached(priority: .userInitiated) {
            // Pre-write temp file for drag-and-drop
            let nsImage = NSImage(cgImage: originalImage, size: NSSize(
                width: originalImage.width, height: originalImage.height
            ))
            TempFileManager.shared.prewriteFile(image: nsImage, id: itemID)

            // Auto-copy to clipboard (on main thread since NSPasteboard requires it)
            if autoCopy {
                await MainActor.run {
                    ClipboardMonitor.shared.skipNextChange()
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([nsImage])
                }
            }

            // Auto-save to file
            if autoSave {
                await MainActor.run {
                    try? AppState.shared.saveToFile(item)
                }
            }
        }
    }

    func removeScreenshot(id: UUID) {
        HapticManager.shared.itemDeleted()
        screenshots.removeAll { $0.id == id }
        TempFileManager.shared.cleanupFile(for: id)
    }

    func clearSession() {
        for item in screenshots {
            TempFileManager.shared.cleanupFile(for: item.id)
        }
        screenshots.removeAll()
    }

    // MARK: - Clipboard

    func copyToClipboard(_ item: ScreenshotItem) {
        ClipboardMonitor.shared.skipNextChange()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item.flattenedImage])

        // Mark as copied — DON'T remove from gallery
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].wasCopied = true
            screenshots[index].copiedAt = Date()
        }

        HapticManager.shared.copyConfirmed()
    }

    // MARK: - Save to File

    @discardableResult
    func saveToFile(_ item: ScreenshotItem) throws -> URL {
        let dir = settings.saveDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        let timestamp = formatter.string(from: item.capturedAt)
        let ext = settings.fileFormat == .png ? "png" : "jpg"
        let filename = "NotchSnap-\(timestamp).\(ext)"
        let fileURL = dir.appendingPathComponent(filename)

        let image = item.flattenedImage
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            throw NSError(domain: "NotchSnap", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image data"])
        }

        let data: Data?
        switch settings.fileFormat {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: settings.jpegQuality])
        }

        guard let imageData = data else {
            throw NSError(domain: "NotchSnap", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }

        try imageData.write(to: fileURL)

        // Update item
        if let index = screenshots.firstIndex(where: { $0.id == item.id }) {
            screenshots[index].savedFileURL = fileURL
        }

        return fileURL
    }

    // MARK: - Clipboard History

    func addClipboardItem(_ item: ClipboardItem) {
        // Avoid consecutive duplicates
        if let last = clipboardItems.first,
           last.previewText == item.previewText && last.type == item.type { return }

        withAnimation(.spring(duration: 0.42, bounce: 0.25)) {
            clipboardItems.insert(item, at: 0)
            if clipboardItems.count > maxClipboardItems {
                clipboardItems.removeLast()
            }
        }
        HapticManager.shared.clipboardItemAdded()
    }

    func removeClipboardItem(id: UUID) {
        clipboardItems.removeAll { $0.id == id }
    }

    // MARK: - Settings

    func updateSettings(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        settings.save()
        applyTheme()
    }

    /// Applies the selected app theme. Called on launch and after any settings change.
    func applyTheme() {
        switch settings.appTheme {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

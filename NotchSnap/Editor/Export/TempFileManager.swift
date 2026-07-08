import Foundation
import AppKit

// MARK: - TempFileManager — Manages temporary PNG files for drag & drop

class TempFileManager: @unchecked Sendable {
    static let shared = TempFileManager()

    private let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("NotchSnap", isDirectory: true)

    /// Shared drag-file URL — every consumer derives the path from here so
    /// the format can change in one place. JPEG since PF-1.
    static func dragFileURL(for id: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchSnap", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).jpg")
    }

    /// Pre-write the drag file to disk for instant drag availability.
    /// PF-1: JPEG at 85% — typically 70-85% smaller than the old full-res
    /// PNG with no visible loss for screen content.
    func prewriteFile(image: NSImage, id: UUID) {
        let url = Self.dragFileURL(for: id)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else { return }

        try? jpegData.write(to: url, options: .atomic)
    }

    /// Remove temp file for a specific screenshot
    func cleanupFile(for itemID: UUID) {
        try? FileManager.default.removeItem(at: Self.dragFileURL(for: itemID))
    }

    /// Remove all temp files (called on app termination)
    func cleanupAll() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

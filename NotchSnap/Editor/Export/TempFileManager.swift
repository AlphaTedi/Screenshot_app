import Foundation
import AppKit

// MARK: - TempFileManager — Manages temporary PNG files for drag & drop

class TempFileManager: @unchecked Sendable {
    static let shared = TempFileManager()

    private let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("NotchSnap", isDirectory: true)

    /// Pre-write a PNG file to disk for instant drag availability
    func prewriteFile(image: NSImage, id: UUID) {
        let url = tempDir.appendingPathComponent("\(id.uuidString).png")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return }

        try? pngData.write(to: url, options: .atomic)
    }

    /// Remove temp file for a specific screenshot
    func cleanupFile(for itemID: UUID) {
        let url = tempDir.appendingPathComponent("\(itemID.uuidString).png")
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove all temp files (called on app termination)
    func cleanupAll() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

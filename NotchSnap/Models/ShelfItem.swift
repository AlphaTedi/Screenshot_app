import Foundation
import AppKit

// MARK: - ShelfItem — one item held on the universal Shelf
//
// The Shelf is a temporary landing pad for anything in transit between
// apps: files, images, text, URLs, and screenshots. Items auto-expire
// unless pinned. Payloads (files/images) live as real files under
// ~/Library/Application Support/NotchSnap/Shelf/ so drag-out is a plain
// file drag; text/URLs are stored inline.

enum ShelfItemType: String, Codable {
    case screenshot
    case file
    case image
    case text
    case url

    var iconName: String {
        switch self {
        case .screenshot: return "camera.viewfinder"
        case .file:       return "doc.fill"
        case .image:      return "photo"
        case .text:       return "text.alignleft"
        case .url:        return "link"
        }
    }
}

struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ShelfItemType
    let createdAt: Date
    var isPinned: Bool
    var expiresAt: Date?          // nil if pinned
    var displayName: String       // filename, or truncated text preview
    var payloadPath: String?      // for files/images/screenshots: absolute path in shelf storage
    var textContent: String?      // for .text and .url

    var payloadURL: URL? {
        payloadPath.map { URL(fileURLWithPath: $0) }
    }

    /// 0...1 — how close the item is to expiring (1 = expired). Pinned → 0.
    func expiryProgress(now: Date = Date()) -> Double {
        guard !isPinned, let expiresAt else { return 0 }
        let total = expiresAt.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(createdAt)
        return min(1, max(0, elapsed / total))
    }
}

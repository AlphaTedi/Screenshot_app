import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ClipboardItem — Classified pasteboard content

struct ClipboardItem: Identifiable {
    let id: UUID
    let capturedAt: Date
    let type: ClipboardItemType
    let rawData: Data?
    let pasteboardTypes: [NSPasteboard.PasteboardType]

    // Derived properties for preview
    var previewText: String?
    var previewImage: NSImage?
    var previewColor: NSColor?
    var sourceURL: URL?
    var fileName: String?

    enum ClipboardItemType: Equatable {
        case screenshot
        case image
        case plainText
        case code
        case url
        case color
        case filePath
        case richText
        case number
        case unknown
    }

    // MARK: - Factory — classify pasteboard content

    static func fromPasteboard(_ pb: NSPasteboard) -> ClipboardItem? {
        // Priority: most specific → most generic

        // 1. Image / Screenshot
        if let image = NSImage(pasteboard: pb) {
            let isScreenshot = pb.types?.contains(.init("com.apple.screencapture")) == true
            return ClipboardItem(
                id: UUID(), capturedAt: Date(),
                type: isScreenshot ? .screenshot : .image,
                rawData: image.tiffRepresentation,
                pasteboardTypes: pb.types ?? [],
                previewImage: image
            )
        }

        // 2. URL
        if let urlString = pb.string(forType: .URL) ?? pb.string(forType: .string),
           let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
            return ClipboardItem(
                id: UUID(), capturedAt: Date(), type: .url,
                rawData: urlString.data(using: .utf8),
                pasteboardTypes: pb.types ?? [],
                previewText: urlString, sourceURL: url
            )
        }

        // 3. Text (code vs plain text vs number vs color)
        if let text = pb.string(forType: .string), !text.isEmpty {
            let detectedType = detectTextType(text)
            var item = ClipboardItem(
                id: UUID(), capturedAt: Date(), type: detectedType,
                rawData: text.data(using: .utf8),
                pasteboardTypes: pb.types ?? [],
                previewText: String(text.prefix(300))
            )
            // If color hex, try to parse NSColor
            if detectedType == .color {
                item.previewColor = NSColor.fromHex(text.trimmingCharacters(in: .whitespaces))
            }
            return item
        }

        // 4. File URL
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
           let fileURL = urls.first {
            return ClipboardItem(
                id: UUID(), capturedAt: Date(), type: .filePath,
                rawData: fileURL.absoluteString.data(using: .utf8),
                pasteboardTypes: pb.types ?? [],
                previewText: fileURL.lastPathComponent,
                sourceURL: fileURL, fileName: fileURL.lastPathComponent
            )
        }

        return nil
    }

    // MARK: - Text Type Detection

    private static func detectTextType(_ text: String) -> ClipboardItemType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Hex color (#RRGGBB or #RGB)
        if trimmed.range(of: "^#[0-9A-Fa-f]{3,8}$", options: .regularExpression) != nil {
            return .color
        }

        // Pure number
        if trimmed.range(of: "^[\\d\\s.,+\\-]+$", options: .regularExpression) != nil {
            return .number
        }

        // Code heuristics
        let codePatterns = ["{", "}", "=>", "->", "func ", "const ", "var ",
                            "import ", "def ", "class ", "return ", "if (", "for (",
                            "let ", "guard ", "switch "]
        let codeScore = codePatterns.filter { text.contains($0) }.count
        if codeScore >= 2 { return .code }

        return .plainText
    }

    // MARK: - Re-copy to pasteboard

    func recopyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch type {
        case .screenshot, .image:
            if let data = rawData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case .color:
            if let text = previewText {
                pb.setString(text, forType: .string)
            }
        default:
            if let text = previewText {
                pb.setString(text, forType: .string)
            }
        }
    }

    // MARK: - SF Symbol icon name

    var iconName: String {
        switch type {
        case .screenshot:  return "camera.viewfinder"
        case .image:       return "photo"
        case .plainText:   return "text.alignleft"
        case .code:        return "chevron.left.forwardslash.chevron.right"
        case .url:         return "link"
        case .color:       return "paintpalette"
        case .filePath:    return "folder"
        case .richText:    return "doc.richtext"
        case .number:      return "number"
        case .unknown:     return "questionmark.circle"
        }
    }

    // MARK: - Relative Time

    var relativeTime: String {
        let interval = Date().timeIntervalSince(capturedAt)
        if interval < 60 { return "ora" }
        if interval < 3600 { return "\(Int(interval / 60)) min fa" }
        if interval < 86400 { return "\(Int(interval / 3600)) h fa" }
        return "\(Int(interval / 86400)) g fa"
    }

    // MARK: - Notch Notification Properties

    var notchIcon: String {
        switch type {
        case .screenshot, .image: return "photo"
        case .plainText:          return "doc.on.doc"
        case .code:               return "curlybraces"
        case .url:                return "link"
        case .color:              return "paintpalette"
        case .filePath:           return "doc.fill"
        case .number:             return "number"
        case .richText:           return "doc.richtext"
        case .unknown:            return "doc.on.doc"
        }
    }

    var notchIconColor: Color {
        switch type {
        case .code:     return Color(nsColor: NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1)) // #34C759
        case .url:      return Color(nsColor: NSColor(red: 0, green: 0.478, blue: 1, alpha: 1))        // #007AFF
        case .filePath: return Color(nsColor: NSColor(red: 1, green: 0.8, blue: 0, alpha: 1))          // #FFCC00
        default:        return .white
        }
    }

    var notchIconFill: Color? {
        guard type == .color, let hex = previewText else { return nil }
        if let nsColor = NSColor.fromHex(hex) {
            return Color(nsColor: nsColor)
        }
        return nil
    }

    var notchRightLabel: String? {
        switch type {
        case .url:
            return sourceURL?.host?.replacingOccurrences(of: "www.", with: "")
        case .color:
            return previewText
        case .filePath:
            return fileName.map { String($0.prefix(16)) }
        case .number:
            return previewText.map { String($0.prefix(12)) }
        default:
            return nil
        }
    }
}

// MARK: - NSColor hex helper

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6 || h.count == 3 else { return nil }

        if h.count == 3 {
            h = h.map { "\($0)\($0)" }.joined()
        }

        guard let val = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

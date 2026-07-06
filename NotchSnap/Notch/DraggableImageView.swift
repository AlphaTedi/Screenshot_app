import AppKit
import UniformTypeIdentifiers

// MARK: - DraggableImageView — Native NSView drag source
//
// Uses the PRE-WRITTEN temp file from TempFileManager (already on disk)
// so drag starts INSTANTLY — no image encoding during the drag.

class DraggableImageView: NSView, NSDraggingSource, NSPasteboardItemDataProvider {

    var screenshotItem: ScreenshotItem?
    var thumbnailImage: NSImage?
    var onTap: (() -> Void)?

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let image = thumbnailImage else { return }

        NSColor.black.setFill()
        bounds.fill()

        // Aspect-FILL: the screenshot covers the whole card, cropped as
        // needed (even very tall captures) — no letterbox bars.
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let fitScale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let drawW = imageSize.width * fitScale
        let drawH = imageSize.height * fitScale
        let drawX = (bounds.width - drawW) / 2
        let drawY = (bounds.height - drawH) / 2
        let drawRect = NSRect(x: drawX, y: drawY, width: drawW, height: drawH)

        // respectFlipped: true compensates for our flipped coordinate system so
        // NSImages backed by CGImage with varying orientation don't render mirrored.
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0,
                   respectFlipped: true, hints: nil)
    }

    // MUST be true — NSViewRepresentable embeds in a flipped SwiftUI coordinate system.
    // Without this, images render upside-down or mirrored.
    override var isFlipped: Bool { true }

    // MARK: - Mouse events

    private var mouseDownEvent: NSEvent?
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let item = screenshotItem,
              let downEvent = mouseDownEvent else { return }

        // Minimum threshold before starting drag
        let dragPoint = convert(event.locationInWindow, from: nil)
        let downPoint = convert(downEvent.locationInWindow, from: nil)
        let distance = hypot(dragPoint.x - downPoint.x, dragPoint.y - downPoint.y)
        guard distance > 3 else { return }

        guard !isDragging else { return }
        isDragging = true
        mouseDownEvent = nil
        HapticManager.shared.dragBegan()

        // Use NSPasteboardItem with LAZY data provider — no encoding upfront
        let pbItem = NSPasteboardItem()

        // File URL from pre-written temp file (INSTANT — already on disk)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchSnap", isDirectory: true)
        let tempURL = tempDir.appendingPathComponent("\(item.id.uuidString).png")

        if FileManager.default.fileExists(atPath: tempURL.path) {
            // File already exists — use it directly
            pbItem.setString(tempURL.absoluteString, forType: .fileURL)

            // Also provide PNG data from the file (fast — just read bytes)
            if let data = try? Data(contentsOf: tempURL) {
                pbItem.setData(data, forType: .init(UTType.png.identifier))
            }
        } else {
            // Fallback: file not yet written — register lazy provider
            pbItem.setDataProvider(self, forTypes: [
                .init(UTType.png.identifier),
                .tiff,
                .fileURL
            ])
        }

        // Create dragging item with the SMALL cached thumbnail as visual
        let draggingItem = NSDraggingItem(pasteboardWriter: pbItem)

        let dragImage = item.cachedThumbnail
        let dragImageSize = NSSize(
            width: min(dragImage.size.width, 200),
            height: min(dragImage.size.height, 200)
        )
        draggingItem.setDraggingFrame(
            NSRect(origin: CGPoint(x: dragPoint.x - dragImageSize.width / 2,
                                   y: dragPoint.y - dragImageSize.height / 2),
                   size: dragImageSize),
            contents: dragImage
        )

        // Start native drag session — INSTANT, no blocking
        beginDraggingSession(with: [draggingItem], event: downEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            onTap?()
        }
        mouseDownEvent = nil
        isDragging = false
    }

    // MARK: - NSPasteboardItemDataProvider (lazy fallback — only called if temp file wasn't ready)

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard let screenshotItem = screenshotItem else { return }

        let image = screenshotItem.flattenedImage

        switch type {
        case .init(UTType.png.identifier):
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                item.setData(pngData, forType: type)
            }

        case .tiff:
            if let tiffData = image.tiffRepresentation {
                item.setData(tiffData, forType: .tiff)
            }

        case .fileURL:
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("NotchSnap", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let url = tempDir.appendingPathComponent("\(screenshotItem.id.uuidString).png")
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url, options: .atomic)
                item.setString(url.absoluteString, forType: .fileURL)
            }

        default:
            break
        }
    }

    // MARK: - NSDraggingSource protocol

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .generic]
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        // Drag ended
    }
}

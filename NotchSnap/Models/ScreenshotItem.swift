import Foundation
import AppKit

// MARK: - Screenshot Item

struct ScreenshotItem: Identifiable {
    let id: UUID
    let capturedAt: Date
    let originalImage: CGImage
    var annotations: [AnnotationModel]
    var savedFileURL: URL?

    // Track copied state for visual feedback (green checkmark badge)
    var wasCopied: Bool = false
    var copiedAt: Date? = nil

    // Pre-computed small thumbnail for fast gallery rendering (generated once at init)
    let cachedThumbnail: NSImage

    init(id: UUID = UUID(), capturedAt: Date = Date(), originalImage: CGImage,
         annotations: [AnnotationModel] = [], savedFileURL: URL? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.originalImage = originalImage
        self.annotations = annotations
        self.savedFileURL = savedFileURL

        // Pre-generate small thumbnail (max 240x160) — fast to render in gallery
        // Uses NSImage(cgImage:size:) for correct orientation (no flip issues)
        let maxW: CGFloat = 240
        let maxH: CGFloat = 160
        let w = CGFloat(originalImage.width)
        let h = CGFloat(originalImage.height)
        let scale = min(maxW / w, maxH / h, 1.0)
        let thumbW = w * scale
        let thumbH = h * scale
        self.cachedThumbnail = NSImage(cgImage: originalImage, size: NSSize(width: thumbW, height: thumbH))
    }

    var hasSavedFile: Bool { savedFileURL != nil }
    var hasAnnotations: Bool { !annotations.isEmpty }

    // MARK: - Metadata for enriched gallery

    var dimensions: String {
        "\(originalImage.width) × \(originalImage.height)"
    }

    var estimatedFileSize: String {
        let bytes = originalImage.width * originalImage.height * 4 // RGBA estimate
        if bytes < 1_000_000 {
            return "\(bytes / 1_000) KB"
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000.0)
        }
    }

    var thumbnail: NSImage {
        cachedThumbnail
    }

    /// Compose original image + all annotations into final NSImage
    var flattenedImage: NSImage {
        let width = originalImage.width
        let height = originalImage.height
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size)
        image.lockFocus()

        // Draw original
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.draw(originalImage, in: CGRect(origin: .zero, size: size))

        // Draw annotations
        for annotation in annotations {
            renderAnnotation(annotation, in: ctx, size: size)
        }

        image.unlockFocus()
        return image
    }

    var flattenedPNGData: Data? {
        let image = flattenedImage
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    // MARK: - Annotation Rendering

    private func renderAnnotation(_ annotation: AnnotationModel, in ctx: CGContext, size: NSSize) {
        switch annotation.tool {
        case .pen(let color, let width, let points):
            guard points.count >= 2 else { return }
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let path = smoothedPath(from: points)
            ctx.addPath(path)
            ctx.strokePath()

        case .text(let content, let color, let fontSize, let origin):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: color
            ]
            let str = NSAttributedString(string: content, attributes: attrs)
            let textSize = str.size()

            // Draw pill background
            let pillRect = CGRect(
                x: origin.x - 4,
                y: origin.y - 2,
                width: textSize.width + 8,
                height: textSize.height + 4
            )
            ctx.setFillColor(color.withAlphaComponent(0.2).cgColor)
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(pillPath)
            ctx.fillPath()

            // Draw text
            str.draw(at: origin)

        case .blur(let rect):
            // Apply pixelation effect
            guard let cropped = originalImage.cropping(to: rect) else { return }
            let ciImage = CIImage(cgImage: cropped)
            let filter = CIFilter(name: "CIPixellate")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(20.0, forKey: kCIInputScaleKey)
            guard let output = filter.outputImage else { return }
            let ciCtx = CIContext()
            guard let blurred = ciCtx.createCGImage(output, from: output.extent) else { return }
            ctx.draw(blurred, in: rect)

        case .arrow(let from, let to, let color, let width):
            ctx.setStrokeColor(color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.setLineWidth(width)

            // Draw line
            ctx.move(to: from)
            ctx.addLine(to: to)
            ctx.strokePath()

            // Draw arrowhead
            let angle = atan2(to.y - from.y, to.x - from.x)
            let headLength: CGFloat = width * 4
            let headAngle: CGFloat = .pi / 6

            let p1 = CGPoint(
                x: to.x - headLength * cos(angle - headAngle),
                y: to.y - headLength * sin(angle - headAngle)
            )
            let p2 = CGPoint(
                x: to.x - headLength * cos(angle + headAngle),
                y: to.y - headLength * sin(angle + headAngle)
            )

            ctx.move(to: to)
            ctx.addLine(to: p1)
            ctx.addLine(to: p2)
            ctx.closePath()
            ctx.fillPath()

        case .rectangle(let rect, let color, let width):
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.stroke(rect)
        }
    }

    /// Catmull-Rom spline smoothing
    private func smoothedPath(from points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 1..<points.count - 1 {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[min(points.count - 1, i + 1)]

            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p2.x - p0.x) / 6, y: p2.y - (p2.y - p0.y) / 6)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return path
    }

    // MARK: - Relative Time

    var relativeTime: String {
        // Localized to the app language (was hardcoded Italian).
        L10n.relativeTime(from: capturedAt)
    }
}

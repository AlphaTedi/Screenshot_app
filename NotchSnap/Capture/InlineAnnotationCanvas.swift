import AppKit
import SwiftUI

// MARK: - InlineAnnotationCanvas — Transparent overlay for drawing annotations on live screen
//
// Annotations are stored in screen-space coordinates (view coordinates).
// When the user captures, they are converted to image-space coordinates.
// Reuses DrawingEngine.smoothedPath() and AnnotationModel/AnnotationTool.

class InlineAnnotationCanvas: NSView {

    // Current tool configuration (set by parent)
    var currentToolType: AnnotationToolType = .pen
    var currentColor: NSColor = .systemRed
    var lineWeight: CGFloat = 4.0
    var fontSize: CGFloat = 18.0

    // Committed annotations (screen-space)
    var annotations: [AnnotationModel] = []
    var redoStack: [AnnotationModel] = []

    // Clip region — only draw within this rect (the selection area)
    var clipRect: CGRect = .zero

    // Current stroke in progress
    private var isDrawing = false
    private var dragStart: CGPoint = .zero
    private var currentPoints: [CGPoint] = []
    private var currentEnd: CGPoint = .zero

    // Text field for inline text input
    private var textField: NSTextField?

    // IMPORTANT: keep this view non-flipped so it shares a coordinate system with
    // its parent AreaSelectorNSView. `clipRect` (== selectionRect in parent space)
    // and mouse-event points must match; otherwise mouseDown's clipRect guard
    // silently rejects clicks in parts of the selection and strokes never get
    // committed (also breaking Undo/Redo because no annotation is ever stored).
    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Clip to selection rect
        ctx.saveGState()
        ctx.clip(to: clipRect)

        // Draw committed annotations
        for annotation in annotations {
            drawAnnotation(annotation, in: ctx)
        }

        // Draw current stroke in progress
        if isDrawing {
            drawCurrentStroke(in: ctx)
        }

        ctx.restoreGState()
    }

    // MARK: - Render a single annotation

    private func drawAnnotation(_ annotation: AnnotationModel, in ctx: CGContext) {
        switch annotation.tool {
        case .pen(let color, let width, let points):
            guard points.count >= 2 else { return }
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(DrawingEngine.smoothedPath(from: points))
            ctx.strokePath()

        case .arrow(let from, let to, let color, let width):
            ctx.setStrokeColor(color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.setLineWidth(width)

            // Line
            ctx.move(to: from)
            ctx.addLine(to: to)
            ctx.strokePath()

            // Arrowhead
            let angle = atan2(to.y - from.y, to.x - from.x)
            let headLength = width * 4
            let headAngle: CGFloat = .pi / 6
            let p1 = CGPoint(x: to.x - headLength * cos(angle - headAngle),
                             y: to.y - headLength * sin(angle - headAngle))
            let p2 = CGPoint(x: to.x - headLength * cos(angle + headAngle),
                             y: to.y - headLength * sin(angle + headAngle))
            ctx.move(to: to)
            ctx.addLine(to: p1)
            ctx.addLine(to: p2)
            ctx.closePath()
            ctx.fillPath()

        case .rectangle(let rect, let color, let width):
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.stroke(rect)

        case .text(let content, let color, let fontSize, let origin):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: color
            ]
            let str = NSAttributedString(string: content, attributes: attrs)
            let textSize = str.size()

            // Background pill
            let pillRect = CGRect(x: origin.x - 4, y: origin.y - 2,
                                  width: textSize.width + 8, height: textSize.height + 4)
            ctx.setFillColor(color.withAlphaComponent(0.2).cgColor)
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(pillPath)
            ctx.fillPath()

            str.draw(at: origin)

        case .blur(let rect):
            // Visual placeholder — gray semi-transparent
            ctx.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
            ctx.fill(rect)
        }
    }

    // MARK: - Draw current stroke preview

    private func drawCurrentStroke(in ctx: CGContext) {
        switch currentToolType {
        case .pen:
            guard currentPoints.count >= 2 else { return }
            ctx.setStrokeColor(currentColor.cgColor)
            ctx.setLineWidth(lineWeight)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(DrawingEngine.smoothedPath(from: currentPoints))
            ctx.strokePath()

        case .arrow:
            ctx.setStrokeColor(currentColor.cgColor)
            ctx.setLineWidth(lineWeight)
            ctx.move(to: dragStart)
            ctx.addLine(to: currentEnd)
            ctx.strokePath()

            // Arrowhead preview
            let angle = atan2(currentEnd.y - dragStart.y, currentEnd.x - dragStart.x)
            let headLength = lineWeight * 4
            let headAngle: CGFloat = .pi / 6
            ctx.setFillColor(currentColor.cgColor)
            let p1 = CGPoint(x: currentEnd.x - headLength * cos(angle - headAngle),
                             y: currentEnd.y - headLength * sin(angle - headAngle))
            let p2 = CGPoint(x: currentEnd.x - headLength * cos(angle + headAngle),
                             y: currentEnd.y - headLength * sin(angle + headAngle))
            ctx.move(to: currentEnd)
            ctx.addLine(to: p1)
            ctx.addLine(to: p2)
            ctx.closePath()
            ctx.fillPath()

        case .rectangle:
            ctx.setStrokeColor(currentColor.cgColor)
            ctx.setLineWidth(lineWeight)
            let rect = normalizedRect(from: dragStart, to: currentEnd)
            ctx.stroke(rect)

        case .blur:
            let rect = normalizedRect(from: dragStart, to: currentEnd)
            ctx.setFillColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(rect)

        case .text:
            break // handled via NSTextField
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard clipRect.contains(point) else { return }

        if currentToolType == .text {
            showTextField(at: point)
            return
        }

        isDrawing = true
        dragStart = point
        currentEnd = point
        currentPoints = [point]
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentEnd = point

        if currentToolType == .pen {
            currentPoints.append(point)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }
        isDrawing = false

        let tool: AnnotationTool
        switch currentToolType {
        case .pen:
            guard currentPoints.count >= 2 else { return }
            tool = .pen(color: currentColor, width: lineWeight, points: currentPoints)
        case .arrow:
            tool = .arrow(from: dragStart, to: currentEnd, color: currentColor, width: lineWeight)
        case .rectangle:
            tool = .rectangle(rect: normalizedRect(from: dragStart, to: currentEnd),
                              color: currentColor, width: lineWeight)
        case .blur:
            tool = .blur(rect: normalizedRect(from: dragStart, to: currentEnd))
        case .text:
            return // handled by text field
        }

        let annotation = AnnotationModel(tool: tool)
        annotations.append(annotation)
        redoStack.removeAll()
        currentPoints.removeAll()
        needsDisplay = true
    }

    // MARK: - Text Input

    private func showTextField(at point: CGPoint) {
        textField?.removeFromSuperview()

        let tf = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 200, height: fontSize + 8))
        tf.font = .systemFont(ofSize: fontSize, weight: .bold)
        tf.textColor = currentColor
        tf.backgroundColor = currentColor.withAlphaComponent(0.15)
        tf.drawsBackground = true
        tf.isBordered = false
        tf.isBezeled = false
        tf.isEditable = true
        tf.isSelectable = true
        tf.focusRingType = .none
        tf.placeholderString = "Testo…"
        tf.target = self
        tf.action = #selector(commitText(_:))
        addSubview(tf)
        textField = tf

        // Make the window key (required so the field editor gets keystrokes)
        // and route first-responder via the window — this inserts the caret.
        if let window {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(tf)
        }
    }

    @objc private func commitText(_ sender: NSTextField) {
        let content = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            sender.removeFromSuperview()
            textField = nil
            return
        }

        let origin = CGPoint(x: sender.frame.origin.x, y: sender.frame.origin.y)
        let tool = AnnotationTool.text(content: content, color: currentColor,
                                       fontSize: fontSize, origin: origin)
        annotations.append(AnnotationModel(tool: tool))
        redoStack.removeAll()
        sender.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }

    // MARK: - Undo / Redo

    func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
        needsDisplay = true
    }

    func redo() {
        guard let last = redoStack.popLast() else { return }
        annotations.append(last)
        needsDisplay = true
    }

    // MARK: - Convert screen-space annotations → image-space

    func convertToImageSpace(imageWidth: Int, imageHeight: Int) -> [AnnotationModel] {
        guard clipRect.width > 0, clipRect.height > 0 else { return [] }

        let scaleX = CGFloat(imageWidth) / clipRect.width
        let scaleY = CGFloat(imageHeight) / clipRect.height
        let originX = clipRect.origin.x
        let originY = clipRect.origin.y

        func toImage(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - originX) * scaleX, y: (p.y - originY) * scaleY)
        }

        func toImageRect(_ r: CGRect) -> CGRect {
            CGRect(x: (r.origin.x - originX) * scaleX,
                   y: (r.origin.y - originY) * scaleY,
                   width: r.width * scaleX, height: r.height * scaleY)
        }

        return annotations.map { annotation in
            let convertedTool: AnnotationTool
            switch annotation.tool {
            case .pen(let color, let width, let points):
                convertedTool = .pen(color: color, width: width * scaleX,
                                     points: points.map { toImage($0) })
            case .arrow(let from, let to, let color, let width):
                convertedTool = .arrow(from: toImage(from), to: toImage(to),
                                       color: color, width: width * scaleX)
            case .rectangle(let rect, let color, let width):
                convertedTool = .rectangle(rect: toImageRect(rect),
                                           color: color, width: width * scaleX)
            case .text(let content, let color, let fontSize, let origin):
                convertedTool = .text(content: content, color: color,
                                      fontSize: fontSize * scaleX, origin: toImage(origin))
            case .blur(let rect):
                convertedTool = .blur(rect: toImageRect(rect))
            }
            return AnnotationModel(id: annotation.id, tool: convertedTool, createdAt: annotation.createdAt)
        }
    }

    // MARK: - Helpers

    private func normalizedRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        CGRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y),
               width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
    }
}

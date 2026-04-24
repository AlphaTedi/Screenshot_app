import SwiftUI
import AppKit

// MARK: - Annotation Canvas View (SwiftUI wrapper)

struct AnnotationCanvasView: NSViewRepresentable {
    @ObservedObject var editorState: EditorState

    func makeNSView(context: Context) -> AnnotationCanvasNSView {
        let view = AnnotationCanvasNSView(editorState: editorState)
        return view
    }

    func updateNSView(_ nsView: AnnotationCanvasNSView, context: Context) {
        nsView.editorState = editorState
        nsView.needsDisplay = true
    }
}

// MARK: - Annotation Canvas NSView (Core Graphics drawing)

class AnnotationCanvasNSView: NSView {
    var editorState: EditorState
    private var currentPoints: [CGPoint] = []
    private var isDrawing = false
    private var dragStart: CGPoint?
    private var textField: NSTextField?

    init(editorState: EditorState) {
        self.editorState = editorState
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw original image — fix coordinate flip for CGImage in flipped NSView
        let imageRect = imageRectInView()
        ctx.saveGState()
        ctx.translateBy(x: imageRect.origin.x, y: imageRect.origin.y + imageRect.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(editorState.item.originalImage, in: CGRect(origin: .zero, size: imageRect.size))
        ctx.restoreGState()

        // Draw all committed annotations
        for annotation in editorState.annotations {
            drawAnnotation(annotation, in: ctx, imageRect: imageRect)
        }

        // Draw current stroke in progress
        if isDrawing {
            drawCurrentStroke(in: ctx, imageRect: imageRect)
        }
    }

    private func imageRectInView() -> CGRect {
        let imgW = CGFloat(editorState.item.originalImage.width)
        let imgH = CGFloat(editorState.item.originalImage.height)
        let scale = min(bounds.width / imgW, bounds.height / imgH)
        let w = imgW * scale
        let h = imgH * scale
        let x = (bounds.width - w) / 2
        let y = (bounds.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Convert view point to image coordinates
    private func viewToImage(_ point: CGPoint) -> CGPoint {
        let rect = imageRectInView()
        let imgW = CGFloat(editorState.item.originalImage.width)
        let imgH = CGFloat(editorState.item.originalImage.height)
        return CGPoint(
            x: (point.x - rect.origin.x) / rect.width * imgW,
            y: (point.y - rect.origin.y) / rect.height * imgH
        )
    }

    /// Convert image point to view coordinates
    private func imageToView(_ point: CGPoint) -> CGPoint {
        let rect = imageRectInView()
        let imgW = CGFloat(editorState.item.originalImage.width)
        let imgH = CGFloat(editorState.item.originalImage.height)
        return CGPoint(
            x: point.x / imgW * rect.width + rect.origin.x,
            y: point.y / imgH * rect.height + rect.origin.y
        )
    }

    // MARK: - Annotation Rendering

    private func drawAnnotation(_ annotation: AnnotationModel, in ctx: CGContext, imageRect: CGRect) {
        switch annotation.tool {
        case .pen(let color, let width, let points):
            guard points.count >= 2 else { return }
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width * imageRect.width / CGFloat(editorState.item.originalImage.width))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let viewPoints = points.map { imageToView($0) }
            let path = DrawingEngine.smoothedPath(from: viewPoints)
            ctx.addPath(path)
            ctx.strokePath()

        case .text(let content, let color, let fontSize, let origin):
            let viewOrigin = imageToView(origin)
            let scaledFontSize = fontSize * imageRect.height / CGFloat(editorState.item.originalImage.height)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: scaledFontSize, weight: .bold),
                .foregroundColor: color
            ]
            let str = NSAttributedString(string: content, attributes: attrs)
            str.draw(at: viewOrigin)

        case .blur(let rect):
            let viewRect = CGRect(
                x: imageToView(rect.origin).x,
                y: imageToView(rect.origin).y,
                width: rect.width / CGFloat(editorState.item.originalImage.width) * imageRect.width,
                height: rect.height / CGFloat(editorState.item.originalImage.height) * imageRect.height
            )
            // Draw pixelated blur placeholder
            ctx.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
            ctx.fill(viewRect)

        case .arrow(let from, let to, let color, let width):
            let vFrom = imageToView(from)
            let vTo = imageToView(to)
            let scaledWidth = width * imageRect.width / CGFloat(editorState.item.originalImage.width)

            ctx.setStrokeColor(color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.setLineWidth(scaledWidth)
            ctx.move(to: vFrom)
            ctx.addLine(to: vTo)
            ctx.strokePath()

            // Arrowhead
            let angle = atan2(vTo.y - vFrom.y, vTo.x - vFrom.x)
            let headLen = scaledWidth * 4
            let headAngle: CGFloat = .pi / 6
            let p1 = CGPoint(x: vTo.x - headLen * cos(angle - headAngle), y: vTo.y - headLen * sin(angle - headAngle))
            let p2 = CGPoint(x: vTo.x - headLen * cos(angle + headAngle), y: vTo.y - headLen * sin(angle + headAngle))
            ctx.move(to: vTo)
            ctx.addLine(to: p1)
            ctx.addLine(to: p2)
            ctx.closePath()
            ctx.fillPath()

        case .rectangle(let rect, let color, let width):
            let viewRect = CGRect(
                x: imageToView(rect.origin).x,
                y: imageToView(rect.origin).y,
                width: rect.width / CGFloat(editorState.item.originalImage.width) * imageRect.width,
                height: rect.height / CGFloat(editorState.item.originalImage.height) * imageRect.height
            )
            let scaledWidth = width * imageRect.width / CGFloat(editorState.item.originalImage.width)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(scaledWidth)
            ctx.stroke(viewRect)
        }
    }

    private func drawCurrentStroke(in ctx: CGContext, imageRect: CGRect) {
        switch editorState.currentTool {
        case .pen:
            guard currentPoints.count >= 2 else { return }
            ctx.setStrokeColor(editorState.currentColor.cgColor)
            ctx.setLineWidth(editorState.brushWidth * imageRect.width / CGFloat(editorState.item.originalImage.width))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let viewPoints = currentPoints.map { imageToView($0) }
            let path = DrawingEngine.smoothedPath(from: viewPoints)
            ctx.addPath(path)
            ctx.strokePath()

        case .arrow, .rectangle, .blur:
            guard let start = dragStart, let end = currentPoints.last else { return }
            let vStart = imageToView(start)
            let vEnd = imageToView(end)

            if editorState.currentTool == .arrow {
                ctx.setStrokeColor(editorState.currentColor.cgColor)
                ctx.setLineWidth(editorState.brushWidth * imageRect.width / CGFloat(editorState.item.originalImage.width))
                ctx.move(to: vStart)
                ctx.addLine(to: vEnd)
                ctx.strokePath()
            } else {
                let rect = normalizedRect(from: vStart, to: vEnd)
                if editorState.currentTool == .blur {
                    ctx.setFillColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
                    ctx.fill(rect)
                } else {
                    ctx.setStrokeColor(editorState.currentColor.cgColor)
                    ctx.setLineWidth(3)
                    ctx.stroke(rect)
                }
            }

        case .text:
            break
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let imgPoint = viewToImage(point)

        switch editorState.currentTool {
        case .pen:
            isDrawing = true
            currentPoints = [imgPoint]

        case .text:
            showTextInput(at: point, imagePoint: imgPoint)

        case .arrow, .rectangle, .blur:
            isDrawing = true
            dragStart = imgPoint
            currentPoints = [imgPoint]
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        let point = convert(event.locationInWindow, from: nil)
        let imgPoint = viewToImage(point)

        switch editorState.currentTool {
        case .pen:
            currentPoints.append(imgPoint)
        case .arrow, .rectangle, .blur:
            if currentPoints.count > 1 {
                currentPoints[currentPoints.count - 1] = imgPoint
            } else {
                currentPoints.append(imgPoint)
            }
        case .text:
            break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }
        isDrawing = false

        let point = convert(event.locationInWindow, from: nil)
        let imgPoint = viewToImage(point)

        switch editorState.currentTool {
        case .pen:
            if currentPoints.count >= 2 {
                let annotation = AnnotationModel(tool: .pen(
                    color: editorState.currentColor,
                    width: editorState.brushWidth,
                    points: currentPoints
                ))
                editorState.addAnnotation(annotation)
            }

        case .arrow:
            if let start = dragStart {
                let annotation = AnnotationModel(tool: .arrow(
                    from: start,
                    to: imgPoint,
                    color: editorState.currentColor,
                    width: editorState.brushWidth
                ))
                editorState.addAnnotation(annotation)
            }

        case .rectangle:
            if let start = dragStart {
                let rect = normalizedRect(from: start, to: imgPoint)
                let annotation = AnnotationModel(tool: .rectangle(
                    rect: rect,
                    color: editorState.currentColor,
                    width: 3
                ))
                editorState.addAnnotation(annotation)
            }

        case .blur:
            if let start = dragStart {
                let rect = normalizedRect(from: start, to: imgPoint)
                let annotation = AnnotationModel(tool: .blur(rect: rect))
                editorState.addAnnotation(annotation)
            }

        case .text:
            break
        }

        currentPoints.removeAll()
        dragStart = nil
        needsDisplay = true
    }

    // MARK: - Text Input

    private func showTextInput(at viewPoint: CGPoint, imagePoint: CGPoint) {
        textField?.removeFromSuperview()

        let tf = NSTextField(frame: NSRect(x: viewPoint.x, y: viewPoint.y, width: 200, height: 28))
        tf.font = .systemFont(ofSize: editorState.fontSize, weight: .bold)
        tf.textColor = editorState.currentColor
        tf.backgroundColor = editorState.currentColor.withAlphaComponent(0.1)
        tf.isBordered = false
        tf.focusRingType = .none
        tf.placeholderString = "Scrivi testo..."
        tf.target = self
        tf.action = #selector(textFieldCommitted(_:))
        tf.tag = Int(imagePoint.x) // store position (simplified)

        addSubview(tf)
        tf.becomeFirstResponder()
        textField = tf
    }

    @objc private func textFieldCommitted(_ sender: NSTextField) {
        guard !sender.stringValue.isEmpty else {
            sender.removeFromSuperview()
            textField = nil
            return
        }

        let viewPoint = sender.frame.origin
        let imgPoint = viewToImage(viewPoint)

        let annotation = AnnotationModel(tool: .text(
            content: sender.stringValue,
            color: editorState.currentColor,
            fontSize: editorState.fontSize,
            origin: imgPoint
        ))
        editorState.addAnnotation(annotation)

        sender.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }

    // MARK: - Helpers

    private func normalizedRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }
}

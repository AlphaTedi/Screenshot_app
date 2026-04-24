import Foundation
import AppKit

// MARK: - Annotation Layer — Manages annotation stack for the canvas

class AnnotationLayer {
    private(set) var annotations: [AnnotationModel] = []
    private var redoStack: [AnnotationModel] = []
    let maxUndoLevels: Int

    init(annotations: [AnnotationModel] = [], maxUndoLevels: Int = 30) {
        self.annotations = annotations
        self.maxUndoLevels = maxUndoLevels
    }

    func add(_ annotation: AnnotationModel) {
        annotations.append(annotation)
        redoStack.removeAll()

        if annotations.count > maxUndoLevels {
            annotations.removeFirst(annotations.count - maxUndoLevels)
        }
    }

    @discardableResult
    func undo() -> AnnotationModel? {
        guard let last = annotations.popLast() else { return nil }
        redoStack.append(last)
        return last
    }

    @discardableResult
    func redo() -> AnnotationModel? {
        guard let last = redoStack.popLast() else { return nil }
        annotations.append(last)
        return last
    }

    var canUndo: Bool { !annotations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
}

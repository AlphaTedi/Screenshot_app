import SwiftUI
import AppKit

// MARK: - Legacy ToolbarView — kept for compatibility
// Wraps the unified AnnotationToolbar with EditorState bindings.

struct ToolbarView: View {
    @ObservedObject var editorState: EditorState
    let onClose: () -> Void

    var body: some View {
        AnnotationToolbar(
            activeTool: $editorState.currentTool,
            activeColor: $editorState.currentColor,
            brushSize: $editorState.brushWidth,
            canUndo: editorState.canUndo,
            canRedo: editorState.canRedo,
            onUndo: { editorState.undo() },
            onRedo: { editorState.redo() }
        )
    }
}

import Foundation
import AppKit

// MARK: - Annotation Tool Types

enum AnnotationToolType: Equatable {
    case pen
    case text
    case blur
    case arrow
    case rectangle
}

enum AnnotationTool {
    case pen(color: NSColor, width: CGFloat, points: [CGPoint])
    case text(content: String, color: NSColor, fontSize: CGFloat, origin: CGPoint)
    case blur(rect: CGRect)
    case arrow(from: CGPoint, to: CGPoint, color: NSColor, width: CGFloat)
    case rectangle(rect: CGRect, color: NSColor, width: CGFloat)

    var toolType: AnnotationToolType {
        switch self {
        case .pen: return .pen
        case .text: return .text
        case .blur: return .blur
        case .arrow: return .arrow
        case .rectangle: return .rectangle
        }
    }
}

// MARK: - Annotation Model

struct AnnotationModel: Identifiable {
    let id: UUID
    let tool: AnnotationTool
    let createdAt: Date

    init(id: UUID = UUID(), tool: AnnotationTool, createdAt: Date = Date()) {
        self.id = id
        self.tool = tool
        self.createdAt = createdAt
    }
}

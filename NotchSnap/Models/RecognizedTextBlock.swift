import Foundation

// MARK: - RecognizedTextBlock — Single recognized text region from Vision OCR

struct RecognizedTextBlock: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Vision normalized coords (0-1, origin bottom-left)

    /// Convert Vision bounding box to SwiftUI display coordinates (origin top-left)
    func displayRect(in imageSize: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1 - boundingBox.maxY) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
    }
}

// MARK: - TextExtractionState

enum TextExtractionState: Equatable {
    case idle
    case analyzing
    case ready
    case noText
    case error(String)

    static func == (lhs: TextExtractionState, rhs: TextExtractionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.analyzing, .analyzing), (.ready, .ready), (.noText, .noText):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

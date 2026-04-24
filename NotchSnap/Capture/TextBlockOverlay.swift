import SwiftUI

// MARK: - TextBlockOverlay — Selectable rectangle for a recognized text block

struct TextBlockOverlay: View {
    let block: RecognizedTextBlock
    let imageSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void

    private var rect: CGRect { block.displayRect(in: imageSize) }

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.30 : 0.12))
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .animation(.spring(duration: 0.15, bounce: 0.2), value: isSelected)
    }
}

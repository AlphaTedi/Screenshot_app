import SwiftUI

// MARK: - DraggableThumbnail — SwiftUI wrapper for native drag-and-drop

struct DraggableThumbnail: NSViewRepresentable {
    let item: ScreenshotItem
    var onTap: (() -> Void)?

    func makeNSView(context: Context) -> DraggableImageView {
        let view = DraggableImageView()
        view.screenshotItem = item
        view.thumbnailImage = item.thumbnail
        view.onTap = onTap
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: DraggableImageView, context: Context) {
        nsView.screenshotItem = item
        nsView.thumbnailImage = item.thumbnail
        nsView.onTap = onTap
        nsView.needsDisplay = true
    }
}

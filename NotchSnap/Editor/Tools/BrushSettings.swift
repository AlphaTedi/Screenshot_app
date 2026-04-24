import SwiftUI

// MARK: - Brush Settings View

struct BrushSettingsView: View {
    @Binding var brushWidth: CGFloat

    private let minWidth: CGFloat = 2
    private let maxWidth: CGFloat = 20

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 4, height: 4)

                Slider(value: $brushWidth, in: minWidth...maxWidth, step: 1)
                    .frame(width: 80)

                Circle()
                    .fill(Color.primary)
                    .frame(width: 14, height: 14)
            }
        }
    }
}

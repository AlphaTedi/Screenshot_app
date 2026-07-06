import SwiftUI

// MARK: - StackedShotsCard — Airbnb-style fanned pile of screenshots
//
// Under the "All" filter, 3+ screenshots collapse into one fanned stack
// (top three captures, white photo-print borders, slight rotations, count
// badge). Clicking the pile opens the full Shots list. Keeps the All view
// compact instead of an endless row.

struct StackedShotsCard: View {
    let items: [ScreenshotItem]
    let onOpen: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fan geometry for back → front cards.
    private static let rotations: [Double] = [-10, 7, -2]
    private static let offsets: [CGSize] = [
        CGSize(width: -14, height: -4),
        CGSize(width: 12, height: -6),
        CGSize(width: 0, height: 2),
    ]

    var body: some View {
        Button(action: onOpen) {
            ZStack {
                // Back-to-front: oldest of the top three at the back.
                let top = Array(items.prefix(3).reversed())
                ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                    let slot = index + (3 - top.count)   // right-align into fan slots
                    photoCard(item)
                        .rotationEffect(.degrees(fanRotation(slot: slot)))
                        .offset(fanOffset(slot: slot))
                        .zIndex(Double(index))
                }

                // Count badge — "12 shots" pinned to the pile's corner.
                Text("\(items.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: 30, y: -34)
                    .zIndex(10)
            }
            .frame(width: 110, height: 100)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.12)
                         : .spring(response: 0.3, dampingFraction: 0.65),
            value: hovering
        )
        .help("Show all screenshots")
    }

    // Hover spreads the fan a touch — invites the click.
    private func fanRotation(slot: Int) -> Double {
        let base = Self.rotations[slot]
        return hovering && !reduceMotion ? base * 1.5 : base
    }

    private func fanOffset(slot: Int) -> CGSize {
        let base = Self.offsets[slot]
        let f: CGFloat = hovering && !reduceMotion ? 1.35 : 1.0
        return CGSize(width: base.width * f, height: base.height * f)
    }

    // One photo-print style card: image with a white border frame.
    private func photoCard(_ item: ScreenshotItem) -> some View {
        Image(nsImage: item.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.white)
            )
            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }
}

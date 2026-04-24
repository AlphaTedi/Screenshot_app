import SwiftUI

// MARK: - ClipboardTile — Visual card for clipboard items in the notch gallery

struct ClipboardTile: View {
    let item: ClipboardItem
    @State private var isHovered = false
    @State private var justCopied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Card background
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 0) {
                // Header: type icon + timestamp
                HStack {
                    Image(systemName: item.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.relativeTime)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Type-specific preview
                previewContent
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                Spacer(minLength: 4)

                // Quick Copy button
                Button(action: quickCopy) {
                    Text(justCopied ? "\u{2713} Copied" : "Quick Copy")
                        .font(.system(size: 10, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(justCopied ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                        )
                        .foregroundStyle(justCopied ? .green : .primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 130, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .shadow(
            color: .black.opacity(isHovered ? 0.35 : 0.15),
            radius: isHovered ? 10 : 4,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(duration: 0.2, bounce: 0.4), value: isHovered)
        .onHover { isHovered = $0 }
    }

    // MARK: - Type-Specific Preview

    @ViewBuilder
    var previewContent: some View {
        switch item.type {
        case .screenshot, .image:
            if let img = item.previewImage {
                // Aspect-FIT inside a fixed slot so the card width stays constant;
                // black letterbox bars fill the empty space for wide/tall captures.
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

        case .color:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(colorFromItem)
                    .frame(width: 32, height: 32)
                Text(item.previewText ?? "")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .frame(height: 42)

        case .code:
            Text(item.previewText ?? "")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.green.opacity(0.9))
                .lineLimit(3)
                .frame(height: 42, alignment: .topLeading)

        case .url:
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(item.sourceURL?.host ?? item.previewText ?? "")
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .frame(height: 42, alignment: .leading)

        case .number:
            Text(item.previewText ?? "")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 42)

        default:
            Text(item.previewText ?? "")
                .font(.system(size: 10))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(height: 42, alignment: .topLeading)
        }
    }

    // MARK: - Helpers

    private var colorFromItem: Color {
        if let nsColor = item.previewColor {
            return Color(nsColor)
        }
        if let hex = item.previewText {
            return Color(nsColor: NSColor.fromHex(hex) ?? .gray)
        }
        return .gray
    }

    private func quickCopy() {
        // Skip next clipboard change so we don't add a duplicate
        ClipboardMonitor.shared.skipNextChange()
        item.recopyToPasteboard()

        withAnimation(.spring(duration: 0.2, bounce: 0.2)) { justCopied = true }
        HapticManager.shared.copyConfirmed()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { justCopied = false }
        }
    }
}

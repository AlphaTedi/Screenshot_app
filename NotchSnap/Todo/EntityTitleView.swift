import AppKit
import SwiftUI

// MARK: - EntityTitleView — a to-do title with inline entity chips (EH-1..7)
//
// SwiftUI Text can't embed views (icons, bordered backgrounds) inside a
// wrapping text flow, so this is the NSAttributedString/NSTextAttachment
// route the urgency/entity PRD §2.3 recommends: each recognized entity
// becomes a pre-rendered chip image attached inline; plain runs stay real
// text; AppKit's layout manager handles wrapping (EH-6).
//
// Clicks: a click on a link chip opens its URL (EH-7, the only interactive
// entity in v1); any other click is forwarded to `onTap` so the row's
// expand/focus behavior still works even though an NSView sits over it.

struct EntityTitleView: NSViewRepresentable {
    let title: String
    let isBright: Bool
    let onTap: () -> Void

    func makeNSView(context: Context) -> EntityTextView {
        let view = EntityTextView()
        view.isEditable = false
        view.isSelectable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        return view
    }

    func updateNSView(_ view: EntityTextView, context: Context) {
        view.onPlainTap = onTap
        view.textStorage?.setAttributedString(
            Self.attributedTitle(title, bright: isBright)
        )
    }

    /// Hugging height: report the wrapped height for the proposed width so
    /// the panel measures chips-in-flow like any other content.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EntityTextView,
                      context: Context) -> CGSize? {
        guard let container = nsView.textContainer,
              let layout = nsView.layoutManager else { return nil }
        let width: CGFloat = {
            if let w = proposal.width, w.isFinite, w > 0 { return w }
            return 100_000   // unconstrained: natural single-line size
        }()
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container)
        return CGSize(width: proposal.width ?? ceil(used.width),
                      height: ceil(used.height))
    }

    // MARK: Attributed assembly

    static func attributedTitle(_ title: String, bright: Bool) -> NSAttributedString {
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(bright ? DSColor.textPrimaryBright : DSColor.textPrimary),
        ]
        let result = NSMutableAttributedString()
        for segment in EntityParser.parse(title) {
            switch segment {
            case .text(let run):
                result.append(NSAttributedString(string: run, attributes: bodyAttributes))
            case .entity(let kind, let display, let url):
                let attachment = NSTextAttachment()
                let image = EntityChipRenderer.image(kind: kind, label: display)
                attachment.image = image
                // Drop the chip slightly below the baseline so it centers
                // against the 13pt body text.
                attachment.bounds = CGRect(x: 0, y: -4.5,
                                           width: image.size.width,
                                           height: image.size.height)
                let chip = NSMutableAttributedString(attachment: attachment)
                if kind == .link, let url {
                    chip.addAttribute(.link, value: url,
                                      range: NSRange(location: 0, length: chip.length))
                }
                // §2.2 margin:0 2px — a thin space each side keeps chips from
                // touching adjacent words.
                result.append(NSAttributedString(string: "\u{2009}", attributes: bodyAttributes))
                result.append(chip)
                result.append(NSAttributedString(string: "\u{2009}", attributes: bodyAttributes))
            }
        }
        return result
    }
}

// MARK: - EntityTextView — click routing

final class EntityTextView: NSTextView {
    var onPlainTap: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) {
        // Deliberately no super: non-selectable label; we only route clicks.
        let point = convert(event.locationInWindow, from: nil)
        if let layout = layoutManager, let container = textContainer,
           let storage = textStorage, storage.length > 0 {
            let glyphIndex = layout.glyphIndex(for: point, in: container)
            let glyphRect = layout.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                                in: container)
            if glyphRect.contains(point) {
                let charIndex = layout.characterIndexForGlyph(at: glyphIndex)
                if charIndex < storage.length,
                   let url = storage.attribute(.link, at: charIndex, effectiveRange: nil) as? URL {
                    NSWorkspace.shared.open(url)   // EH-7
                    return
                }
            }
        }
        onPlainTap?()
    }
}

// MARK: - EntityChipRenderer — chips as cached NSImages
//
// Metrics mirror DSEntityChip / EntityChipReference exactly (EH-5): radius 5,
// padding 1×7, 12pt label (monospaced for code), 10pt SF Symbol icon, only
// colors and icon differ per kind.

@MainActor
enum EntityChipRenderer {
    static let chipHeight: CGFloat = 18

    private static var cache: [String: NSImage] = [:]

    static func image(kind: EntityKind, label: String) -> NSImage {
        let key = "\(kind)|\(label)"
        if let cached = cache[key] { return cached }

        let font: NSFont = kind == .code
            ? .monospacedSystemFont(ofSize: 12, weight: .regular)
            : .systemFont(ofSize: 12)
        let textColor = NSColor(DSEntityChip.text(for: kind))
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: textColor,
        ]
        let textSize = (label as NSString).size(withAttributes: textAttributes)

        var icon: NSImage?
        if let symbolName = DSEntityChip.sfSymbol(for: kind),
           let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
               .withSymbolConfiguration(.init(pointSize: 10, weight: .medium)) {
            icon = symbol.tinted(with: textColor)
        }
        let iconAdvance: CGFloat = icon.map { $0.size.width + 4 } ?? 0

        let size = NSSize(width: ceil(7 + iconAdvance + textSize.width + 7),
                          height: chipHeight)
        let background = NSColor(DSEntityChip.background(for: kind))
        let border = NSColor(DSEntityChip.border(for: kind))

        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                    xRadius: 5, yRadius: 5)
            background.setFill()
            path.fill()
            border.setStroke()
            path.lineWidth = 0.5
            path.stroke()

            var x: CGFloat = 7
            if let icon {
                icon.draw(at: NSPoint(x: x, y: (rect.height - icon.size.height) / 2),
                          from: .zero, operation: .sourceOver, fraction: 1)
                x += icon.size.width + 4
            }
            (label as NSString).draw(
                at: NSPoint(x: x, y: (rect.height - textSize.height) / 2),
                withAttributes: textAttributes
            )
            return true
        }
        cache[key] = image
        return image
    }
}

private extension NSImage {
    /// Color fill masked by the symbol's alpha — standard template tinting.
    func tinted(with color: NSColor) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.set()
            rect.fill()
            self.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
    }
}

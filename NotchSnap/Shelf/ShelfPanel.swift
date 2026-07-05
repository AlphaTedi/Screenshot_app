import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - ShelfPanelController — the bottom-left landing pad
//
// Generalizes the old single-screenshot corner preview into a strip of
// Shelf cards. Reveals itself when items are added, hides after a delay
// (hover pauses it), and re-reveals when the cursor visits the
// bottom-left hot corner. Items can be dragged out, pinned, copied,
// or removed; new files/text/images can be dropped straight onto it.

@MainActor
final class ShelfPanelController {
    static let shared = ShelfPanelController()

    private var panel: NSPanel?
    private var hideWork: Task<Void, Never>?
    private var cancellable: AnyCancellable?
    private var cornerMonitor: Any?
    private var lastCount = 0

    private let margin: CGFloat = 20

    func setup() {
        lastCount = ShelfStore.shared.items.count

        // Reveal on new items; close when emptied.
        cancellable = ShelfStore.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                if items.isEmpty {
                    self.hide(animated: true)
                } else {
                    if items.count > self.lastCount {
                        self.reveal()
                    } else {
                        self.refreshFrame()
                    }
                }
                self.lastCount = items.count
            }

        // Hot corner: cursor entering the bottom-left corner re-reveals the shelf.
        cornerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel == nil || self.panel?.isVisible == false,
                      !ShelfStore.shared.items.isEmpty,
                      let screen = NSScreen.main else { return }
                let loc = NSEvent.mouseLocation
                let hot = NSRect(x: screen.visibleFrame.minX,
                                 y: screen.visibleFrame.minY,
                                 width: 6, height: 120)
                if hot.contains(loc) { self.reveal() }
            }
        }
    }

    // MARK: - Reveal / hide

    func reveal() {
        guard !ShelfStore.shared.items.isEmpty, let screen = NSScreen.main else { return }

        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            p.level = .floating
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let host = NSHostingView(rootView: ShelfStripView(
                onHoverChanged: { [weak self] hovering in
                    if hovering { self?.cancelHide() } else { self?.scheduleHide(after: 3) }
                }
            ))
            p.contentView = host
            self.panel = p
        }

        guard let panel else { return }
        let size = fittingSize()
        let target = NSRect(
            x: screen.visibleFrame.minX + margin,
            y: screen.visibleFrame.minY + margin,
            width: size.width, height: size.height
        )

        if !panel.isVisible {
            var start = target
            start.origin.x = screen.visibleFrame.minX - size.width - 40
            panel.setFrame(start, display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.32
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
                panel.animator().setFrame(target, display: true)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.setFrame(target, display: true)
        }

        scheduleHide(after: 8)
    }

    private func refreshFrame() {
        guard let panel, panel.isVisible, let screen = NSScreen.main else { return }
        let size = fittingSize()
        panel.setFrame(NSRect(
            x: screen.visibleFrame.minX + margin,
            y: screen.visibleFrame.minY + margin,
            width: size.width, height: size.height
        ), display: true)
    }

    private func fittingSize() -> NSSize {
        let count = min(ShelfStore.shared.items.count, 5)
        let width = CGFloat(count) * (ShelfCard.cardWidth + 8) - 8 + 24
        return NSSize(width: max(width, ShelfCard.cardWidth + 24), height: ShelfCard.cardHeight + 24)
    }

    func hide(animated: Bool) {
        cancelHide()
        guard let panel, panel.isVisible else { return }
        if animated, let screen = NSScreen.main {
            var out = panel.frame
            out.origin.x = screen.visibleFrame.minX - out.width - 40
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(out, display: true)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }

    private func scheduleHide(after seconds: Double) {
        cancelHide()
        hideWork = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide(animated: true)
        }
    }

    private func cancelHide() {
        hideWork?.cancel()
        hideWork = nil
    }
}

// MARK: - Drop handling (shared by the strip and the expanded notch)

enum ShelfDropHandler {
    static let acceptedTypes: [UTType] = [.fileURL, .image, .url, .plainText]

    @discardableResult
    static func handle(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in ShelfStore.shared.addFile(from: url) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in ShelfStore.shared.addImageData(data) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in ShelfStore.shared.addText(url.absoluteString) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    let text: String?
                    if let s = data as? String { text = s }
                    else if let d = data as? Data { text = String(data: d, encoding: .utf8) }
                    else { text = nil }
                    guard let text else { return }
                    Task { @MainActor in ShelfStore.shared.addText(text) }
                }
            }
        }
        return handled
    }
}

// MARK: - ShelfStripView — horizontal row of cards

private struct ShelfStripView: View {
    @ObservedObject private var store = ShelfStore.shared
    let onHoverChanged: (Bool) -> Void
    @State private var dropTargeted = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.items) { item in
                    ShelfCard(item: item)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(dropTargeted ? Color.accentColor : Color.white.opacity(0.15),
                        lineWidth: dropTargeted ? 2 : 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: store.items)
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
        .onHover(perform: onHoverChanged)
        .onDrop(of: ShelfDropHandler.acceptedTypes, isTargeted: $dropTargeted) { providers in
            ShelfDropHandler.handle(providers: providers)
        }
    }
}

// MARK: - ShelfCard — one item

struct ShelfCard: View {
    static let cardWidth: CGFloat = 96
    static let cardHeight: CGFloat = 96

    let item: ShelfItem
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(width: Self.cardWidth - 12, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(Color.accentColor))
                        .offset(x: 4, y: -4)
                }
            }

            Text(item.displayName)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            HStack(spacing: 3) {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 7))
                Text(item.type.rawValue.capitalized)
                    .font(.system(size: 8))
            }
            .foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.10 : 0.05))
        )
        // Expiry cue: the card quietly fades as it approaches expiry.
        .opacity(1.0 - 0.35 * item.expiryProgress())
        .overlay(alignment: .bottomTrailing) {
            if hovering { hoverActions }
        }
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hovering)
        .onDrag { dragProvider() }
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") { ShelfStore.shared.togglePin(item.id) }
            Button("Copy") { copyToPasteboard() }
            Divider()
            Button("Remove", role: .destructive) { ShelfStore.shared.remove(item.id) }
        }
    }

    // MARK: Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.payloadURL,
           item.type == .image || item.type == .screenshot,
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = item.payloadURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(6)
        } else {
            ZStack {
                Color.primary.opacity(0.06)
                VStack(spacing: 2) {
                    Image(systemName: item.type.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(item.type == .url ? Color.blue : .secondary)
                    Text(item.textContent ?? "")
                        .font(.system(size: 7))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: Hover actions

    private var hoverActions: some View {
        HStack(spacing: 4) {
            ShelfMiniButton(icon: item.isPinned ? "pin.slash" : "pin") {
                ShelfStore.shared.togglePin(item.id)
            }
            ShelfMiniButton(icon: "xmark") {
                ShelfStore.shared.remove(item.id)
            }
        }
        .padding(4)
        .transition(.opacity)
    }

    // MARK: Drag-out / copy

    private func dragProvider() -> NSItemProvider {
        if let url = item.payloadURL,
           let provider = NSItemProvider(contentsOf: url) {
            return provider   // native file drag — Finder, Mail, Slack all accept
        }
        if item.type == .url, let s = item.textContent, let url = URL(string: s) {
            return NSItemProvider(object: url as NSURL)
        }
        return NSItemProvider(object: (item.textContent ?? item.displayName) as NSString)
    }

    private func copyToPasteboard() {
        ClipboardMonitor.shared.skipNextChange()
        let pb = NSPasteboard.general
        pb.clearContents()
        if let url = item.payloadURL,
           item.type == .image || item.type == .screenshot,
           let img = NSImage(contentsOf: url) {
            pb.writeObjects([img])
        } else if let url = item.payloadURL {
            pb.writeObjects([url as NSURL])
        } else if let text = item.textContent {
            pb.setString(text, forType: .string)
        }
        HapticManager.shared.copyConfirmed()
    }
}

private struct ShelfMiniButton: View {
    let icon: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.black.opacity(hover ? 0.75 : 0.55)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

import SwiftUI

// MARK: - Expanded Notch View — Gallery with screenshots + clipboard items

struct NotchExpandedView: View {
    @EnvironmentObject var appState: AppState
    @State private var appeared = false

    private var hasContent: Bool {
        !appState.screenshots.isEmpty || !appState.clipboardItems.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasContent {
                galleryView
            } else {
                emptyState
            }
            shortcutLegend
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.5))
                .scaleEffect(appeared ? 1.0 : 0.6)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.38, dampingFraction: 0.62), value: appeared)

            Text("Nessun contenuto ancora.\nFai uno screenshot o copia qualcosa.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.04), value: appeared)
        }
        .padding()
    }

    // MARK: - Shortcut Legend

    private var shortcutLegend: some View {
        HStack(spacing: 12) {
            ShortcutBadge(keys: "\u{2303}\u{21E7}4", description: "Area")
            ShortcutBadge(keys: "\u{2303}\u{21E7}3", description: "Schermo")
            ShortcutBadge(keys: "\u{2303}\u{21E7}5", description: "Area + Edit")
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.2).delay(0.18), value: appeared)
    }

    // MARK: - Gallery — screenshots first, then clipboard items

    private var galleryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                // Screenshots (draggable)
                ForEach(Array(appState.screenshots.enumerated()), id: \.element.id) { index, item in
                    ScreenshotThumbnailView(item: item)
                        .scaleEffect(appeared ? 1.0 : 0.65)
                        .opacity(appeared ? 1.0 : 0.0)
                        .offset(y: appeared ? 0 : -8)
                        .animation(NotchAnimation.cardEntry(index: index), value: appeared)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.72, anchor: .trailing)),
                                removal: .move(edge: .leading)
                                    .combined(with: .opacity)
                            )
                        )
                }

                // Separator if both exist
                if !appState.screenshots.isEmpty && !appState.clipboardItems.isEmpty {
                    Divider()
                        .frame(height: 60)
                        .opacity(0.3)
                        .padding(.horizontal, 4)
                }

                // Clipboard items
                ForEach(Array(appState.clipboardItems.enumerated()), id: \.element.id) { index, item in
                    ClipboardTile(item: item)
                        .scaleEffect(appeared ? 1.0 : 0.65)
                        .opacity(appeared ? 1.0 : 0.0)
                        .offset(y: appeared ? 0 : -8)
                        .animation(
                            NotchAnimation.cardEntry(index: appState.screenshots.count + index),
                            value: appeared
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.72, anchor: .trailing)),
                                removal: .move(edge: .leading)
                                    .combined(with: .opacity)
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(NotchAnimation.newScreenshot, value: appState.screenshots.map(\.id))
        .animation(NotchAnimation.newScreenshot, value: appState.clipboardItems.map(\.id))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }
}

// MARK: - Shortcut Badge

struct ShortcutBadge: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.12))
                .cornerRadius(4)
            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

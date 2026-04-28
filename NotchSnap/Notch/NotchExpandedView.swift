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

            Text("No content yet.\nTake a screenshot or copy something.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.04), value: appeared)
        }
        .padding()
    }

    private var galleryTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.72, anchor: .trailing)),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Gallery — screenshots first, then clipboard items

    private var galleryView: some View {
        // PERF: dropped per-card staggered cardEntry animations and `.map(\.id)`
        // dependency arrays. With many items they were O(N) every body rebuild
        // and every appeared toggle would fire N stacked springs simultaneously.
        // Lazy stack diffing + transition() handle insert/remove animation cleanly.
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(appState.screenshots) { item in
                    ScreenshotThumbnailView(item: item)
                        .transition(galleryTransition)
                }

                if !appState.screenshots.isEmpty && !appState.clipboardItems.isEmpty {
                    Divider()
                        .frame(height: 60)
                        .opacity(0.3)
                        .padding(.horizontal, 4)
                }

                ForEach(appState.clipboardItems) { item in
                    ClipboardTile(item: item)
                        .transition(galleryTransition)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(NotchAnimation.newScreenshot, value: appState.screenshots.count)
        .animation(NotchAnimation.newScreenshot, value: appState.clipboardItems.count)
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

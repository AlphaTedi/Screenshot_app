import SwiftUI

// MARK: - Content filter

// Shared with NotchRootView, which needs to know whether the filter bar is
// visible so the notch shape can grow to make room for it.
extension AppState {
    var notchAvailableFilters: [NotchContentFilter] {
        var result: [NotchContentFilter] = []
        // Tray and Notes are always offered — they're tools, not content.
        result.append(.tray)
        result.append(.notes)
        if !screenshots.isEmpty
            || clipboardItems.contains(where: { $0.type == .screenshot || $0.type == .image }) {
            result.append(.screenshots)
        }
        if !snippets.isEmpty {
            result.append(.snippets)
        }
        if clipboardItems.contains(where: { $0.type == .url }) {
            result.append(.links)
        }
        if clipboardItems.contains(where: {
            $0.type != .url && $0.type != .screenshot && $0.type != .image
        }) {
            result.append(.text)
        }
        return result
    }

    /// Only show the bar when there's more than one category to switch between.
    var showsNotchFilterBar: Bool {
        notchAvailableFilters.count >= 2
    }
}

enum NotchContentFilter: String, CaseIterable, Identifiable {
    case all, tray, screenshots, snippets, links, text, notes
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:         return L10n.t("filter.all")
        case .tray:        return L10n.t("filter.tray")
        case .screenshots: return L10n.t("filter.shots")
        case .snippets:    return L10n.t("filter.snippets")
        case .links:       return L10n.t("filter.links")
        case .text:        return L10n.t("filter.text")
        case .notes:       return L10n.t("filter.notes")
        }
    }

    var icon: String {
        switch self {
        case .all:         return "square.grid.2x2"
        case .tray:        return "tray.full"
        case .screenshots: return "camera.viewfinder"
        case .snippets:    return "text.badge.star"
        case .links:       return "link"
        case .text:        return "text.alignleft"
        case .notes:       return "note.text"
        }
    }
}

// MARK: - Expanded Notch View — Gallery with screenshots + clipboard items

struct NotchExpandedView: View {
    @EnvironmentObject var appState: AppState
    // Re-render when the language override changes.
    @AppStorage(L10n.storageKey) private var appLanguage = "system"
    @ObservedObject private var shelf = ShelfStore.shared
    @State private var appeared = false
    @State private var filter: NotchContentFilter = .all
    @State private var shelfDropTargeted = false

    private var hasContent: Bool {
        !appState.screenshots.isEmpty || !appState.clipboardItems.isEmpty
            || !shelf.items.isEmpty || !appState.snippets.isEmpty
            || !appState.pinnedItems.isEmpty
    }

    // MARK: - Filtered collections

    private var filteredScreenshots: [ScreenshotItem] {
        switch filter {
        case .all, .screenshots: return appState.screenshots
        default:                 return []
        }
    }

    private var filteredClipboardItems: [ClipboardItem] {
        switch filter {
        case .all:
            return appState.clipboardItems
        case .screenshots:
            return appState.clipboardItems.filter { $0.type == .screenshot || $0.type == .image }
        case .links:
            return appState.clipboardItems.filter { $0.type == .url }
        case .text:
            return appState.clipboardItems.filter {
                $0.type != .url && $0.type != .screenshot && $0.type != .image
            }
        case .tray, .snippets, .notes:
            return []
        }
    }

    private var showsTraySection: Bool { filter == .all || filter == .tray }
    private var showsSnippetSection: Bool { filter == .all || filter == .snippets }

    private var availableFilters: [NotchContentFilter] { appState.notchAvailableFilters }
    private var showsFilterBar: Bool { appState.showsNotchFilterBar }

    var body: some View {
        VStack(spacing: 0) {
            // The bar always shows — Tray and Notes are tools that must stay
            // reachable even before any content exists.
            if showsFilterBar {
                filterBar
            }
            if filter == .notes {
                NotesTabView()
            } else if filter == .tray && shelf.items.isEmpty {
                TrayEmptyState()
            } else if hasContent {
                galleryView
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The expanded notch is the tray's drop target: files, images, text
        // and links dragged here fall into the Tray section.
        .onDrop(of: ShelfDropHandler.acceptedTypes, isTargeted: $shelfDropTargeted) { providers in
            let handled = ShelfDropHandler.handle(providers: providers)
            if handled {
                // Stay on the Tray so the user sees the item fall in.
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    filter = .tray
                }
            }
            return handled
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 2)
                .padding(6)
                .opacity(shelfDropTargeted ? 1 : 0)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.15), value: shelfDropTargeted)
        )
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
            consumePendingFilter()
            // Keep the gallery lean — drop rolling history older than 8h.
            appState.pruneStaleClipboardItems()
        }
        .onChange(of: appState.pendingNotchFilter) { _ in
            consumePendingFilter()
        }
        .onDisappear {
            appeared = false
        }
        .onChange(of: filter) { f in
            appState.activeNotchFilter = f
        }
        .onChange(of: showsFilterBar) { shows in
            // If content shrank to a single category, fall back to All so
            // the user is never stuck on a hidden filter.
            if !shows { filter = .all }
        }
    }

    /// Apply a one-shot filter request (e.g. drag-to-notch opens the Tray).
    private func consumePendingFilter() {
        guard let requested = appState.pendingNotchFilter else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            filter = requested
        }
        appState.pendingNotchFilter = nil
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach([NotchContentFilter.all] + availableFilters) { f in
                FilterChip(filter: f, isActive: filter == f) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        filter = f
                    }
                }
            }
            Spacer()

            // "Clean up the tray" — clears everything unpinned.
            if !shelf.items.isEmpty && (filter == .all || filter == .tray) {
                ClearTrayChip {
                    ShelfStore.shared.clearUnpinned()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
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

            Text(L10n.t("notch.empty"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.04), value: appeared)
        }
        .padding()
    }

    private var sectionDivider: some View {
        Divider()
            .frame(height: 60)
            .opacity(0.3)
            .padding(.horizontal, 4)
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
            LazyHStack(alignment: .center, spacing: 10) {
                // 1. SNIPPETS — always the front spot: the things you reuse
                //    every day should be one glance away.
                if showsSnippetSection {
                    ForEach(appState.snippets) { item in
                        ClipboardTile(item: item)
                            .transition(galleryTransition)
                    }
                    NewSnippetTile()
                    if filter == .all { sectionDivider }
                }

                // 2. TRAY — files in transit; they "fall in" when dropped.
                if showsTraySection {
                    ForEach(shelf.items) { item in
                        TrayCard(item: item)
                            .transition(galleryTransition)
                    }
                    if filter == .all && !shelf.items.isEmpty { sectionDivider }
                }

                // 3. SHOTS
                ForEach(filteredScreenshots) { item in
                    ScreenshotThumbnailView(item: item)
                        .transition(galleryTransition)
                }

                // 4. PINNED + RECENT clipboard
                if filter == .all {
                    ForEach(appState.pinnedItems) { item in
                        ClipboardTile(item: item)
                            .transition(galleryTransition)
                    }
                    if (!filteredScreenshots.isEmpty || !appState.pinnedItems.isEmpty)
                        && !filteredClipboardItems.isEmpty {
                        sectionDivider
                    }
                } else if !filteredScreenshots.isEmpty && !filteredClipboardItems.isEmpty {
                    sectionDivider
                }

                ForEach(filteredClipboardItems) { item in
                    ClipboardTile(item: item)
                        .transition(galleryTransition)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        // Clear gap between the chips and the previews below them.
        .padding(.top, showsFilterBar ? 4 : 0)
        .animation(NotchAnimation.newScreenshot, value: appState.screenshots.count)
        .animation(NotchAnimation.newScreenshot, value: appState.clipboardItems.count)
        // Bouncier spring for the tray so drops visibly "land"
        .animation(.spring(response: 0.42, dampingFraction: 0.6), value: shelf.items.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: filter)
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

// MARK: - Clear Tray Chip

private struct ClearTrayChip: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                    .font(.system(size: 9, weight: .semibold))
                Text(L10n.t("tray.clear"))
                    .font(.system(size: 10, weight: .medium))
            }
            // Destructive styling — this deletes tray content.
            .foregroundStyle(hover ? Color.white : Color.red.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(hover ? Color.red.opacity(0.85) : Color.red.opacity(0.15))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let filter: NotchContentFilter
    let isActive: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(filter.label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? Color.black : Color.white.opacity(hover ? 0.9 : 0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.9)
                          : Color.white.opacity(hover ? 0.14 : 0.08))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
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

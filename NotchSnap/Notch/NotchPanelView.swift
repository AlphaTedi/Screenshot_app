import SwiftUI

// MARK: - NotchPanelView — Root SwiftUI view for the notch panel

struct NotchPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer (notch area — invisible)
            Spacer()
                .frame(height: appState.isNotchExpanded ? 0 : 0)

            if appState.isNotchExpanded {
                NotchExpandedView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                NotchCollapsedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: appState.isNotchExpanded)
    }
}

// MARK: - Collapsed View

struct NotchCollapsedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Invisible — notch area
            Color.clear

            // Badge counter
            if appState.settings.showBadgeCounter && !appState.screenshots.isEmpty {
                HStack {
                    Spacer()
                    Text("\(appState.screenshots.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: -4, y: 4)
                }
            }
        }
    }
}

import SwiftUI

// MARK: - NotchRootView — Connects NotchShapeView with gallery content

struct NotchRootView: View {
    @ObservedObject var controller: NotchController
    @EnvironmentObject var appState: AppState

    var body: some View {
        NotchShapeView(
            state: $controller.state,
            notchSize: controller.notchSize,
            expandedSize: controller.expandedSize,
            // Grow for the filter-chip bar, and further for the Notes tab
            // (composer + lists need more vertical room than tiles).
            extraExpandedHeight: (appState.showsNotchFilterBar ? 34 : 0)
                + (appState.activeNotchFilter == .notes ? 44 : 0),
            extraExpandedWidth: appState.activeNotchFilter == .notes ? 140 : 0,
            hasPhysicalNotch: controller.hasPhysicalNotch,
            screenshotJustArrived: controller.screenshotJustArrived,
            contentVisible: controller.contentVisible,
            notificationContentVisible: controller.notificationContentVisible,
            notificationWide: controller.notificationWide,
            content: AnyView(
                NotchExpandedView()
                    .environmentObject(appState)
                    .onHover { hovering in
                        if hovering {
                            controller.cancelCollapse()
                        } else {
                            controller.triggerCollapse()
                        }
                    }
            ),
            notificationContent: AnyView(
                NotchNotificationContent(controller: controller)
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

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

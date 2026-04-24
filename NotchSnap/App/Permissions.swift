import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Permission Manager
//
// IMPORTANT: Never call CGRequestScreenCaptureAccess() or CGPreflightScreenCaptureAccess()
// — these trigger the system popup every time. Instead, check permission passively
// by attempting SCShareableContent and seeing if it succeeds.

@MainActor
class PermissionManager: ObservableObject {
    @Published var hasScreenRecording: Bool = false
    @Published var hasAccessibility: Bool = true
    @Published var currentStep: OnboardingStep = .screenRecording
    @Published var onboardingCompleted: Bool

    private var pollingTimer: Timer?

    private static let onboardingCompletedKey = "notchsnap.onboardingCompleted"

    enum OnboardingStep: Int, CaseIterable {
        case screenRecording
        case tutorial
        case complete
    }

    init() {
        self.onboardingCompleted = UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
    }

    // MARK: - Check Permissions (passive — no system prompts)

    func checkAllPermissions() {
        checkScreenRecording()
    }

    func checkScreenRecording() {
        // Passive check via SCShareableContent — does NOT trigger system popup
        Task {
            if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
               !content.displays.isEmpty {
                hasScreenRecording = true
            }
        }
    }

    var allPermissionsGranted: Bool {
        hasScreenRecording
    }

    var shouldShowOnboarding: Bool {
        !onboardingCompleted && !allPermissionsGranted
    }

    // MARK: - Request Permissions (only opens System Preferences — no system popup)

    func requestScreenRecording() {
        // Only open System Preferences — do NOT call CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func requestAccessibility() {
        // No-op
    }

    // MARK: - Polling (passive check)

    func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllPermissions()
                if self?.allPermissionsGranted == true {
                    self?.pollingTimer?.invalidate()
                    self?.pollingTimer = nil
                }
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Advance Step

    func advanceStep() {
        guard let nextIndex = OnboardingStep.allCases.firstIndex(of: currentStep)
                .map({ OnboardingStep.allCases.index(after: $0) }),
              nextIndex < OnboardingStep.allCases.endIndex
        else { return }
        currentStep = OnboardingStep.allCases[nextIndex]
    }

    // MARK: - Complete Onboarding

    func completeOnboarding() {
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        stopPolling()
    }
}

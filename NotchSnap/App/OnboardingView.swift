import SwiftUI
import ScreenCaptureKit

// MARK: - OnboardingFlowView — 2-step onboarding (Welcome → Permissions)

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @AppStorage("onboardingVersion") var onboardingVersion: Int = 0

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            Group {
                if currentStep == 0 {
                    OnboardingWelcomeView(onAdvance: advanceStep)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    OnboardingPermissionsView(onComplete: completeOnboarding)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
        }
        .frame(width: 560, height: 480)
        .overlay(alignment: .bottom) {
            StepDotIndicator(current: currentStep, total: 2)
                .padding(.bottom, 12)
        }
    }

    func advanceStep() {
        SoundPlayer.shared.play("step_advance")
        withAnimation { currentStep += 1 }
    }

    func completeOnboarding() {
        SoundPlayer.shared.play("onboarding_complete")
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        onboardingVersion = 1
        OnboardingWindowController.dismiss()
        // Warm the capture cache now that permission may have been granted
        CaptureManager.shared.warmContentCache()
    }
}

// MARK: - Step Dot Indicator

struct StepDotIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == current ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - Visual Effect Background (blur wallpaper)

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Welcome View (Step 1)

struct OnboardingWelcomeView: View {
    var onAdvance: () -> Void
    @State private var iconAppeared = false
    @State private var textAppeared = false
    @State private var previewAppeared = false
    @State private var buttonAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            // App icon with bounce
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .scaleEffect(iconAppeared ? 1.0 : 0.5)
                .opacity(iconAppeared ? 1.0 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: iconAppeared)
                .padding(.top, 48)

            Spacer().frame(height: 20)

            Text("NotchSnap")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .opacity(textAppeared ? 1.0 : 0)
                .offset(y: textAppeared ? 0 : 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: textAppeared)

            Text("Your screenshots, always within reach of the notch.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(textAppeared ? 1.0 : 0)
                .offset(y: textAppeared ? 0 : 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: textAppeared)

            Spacer().frame(height: 32)

            // Mini preview
            NotchMiniPreview()
                .frame(height: 120)
                .padding(.horizontal, 48)
                .opacity(previewAppeared ? 1.0 : 0)
                .scaleEffect(previewAppeared ? 1.0 : 0.95)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: previewAppeared)

            Spacer()

            // CTA button
            Button(action: onAdvance) {
                HStack {
                    Text("Get Started")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
            .padding(.horizontal, 48)
            .opacity(buttonAppeared ? 1.0 : 0)
            .offset(y: buttonAppeared ? 0 : 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.55), value: buttonAppeared)
            .padding(.bottom, 40)
        }
        .onAppear {
            iconAppeared = true
            textAppeared = true
            previewAppeared = true
            buttonAppeared = true
        }
    }
}

// MARK: - Permissions View (Step 2)

struct OnboardingPermissionsView: View {
    var onComplete: () -> Void
    @State var screenRecordingGranted = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Set up NotchSnap")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.top, 40)

            Text("Grant permissions to use all features.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.horizontal, 48)

            Spacer().frame(height: 32)

            // Permission card
            VStack(spacing: 12) {
                PermissionCard(
                    icon: "camera.viewfinder",
                    iconColor: .blue,
                    title: "Screen Recording",
                    description: "Needed to capture screenshots. We never record or save your screen.",
                    isGranted: screenRecordingGranted,
                    onGrant: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                        )
                    }
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Footer buttons
            VStack(spacing: 10) {
                Button(action: onComplete) {
                    Text(screenRecordingGranted ? "Start using NotchSnap \u{2192}" : "Get Started \u{2192}")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
                .padding(.horizontal, 48)

                if !screenRecordingGranted {
                    Button("Skip for now") { onComplete() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
            }
            .padding(.bottom, 36)
        }
        .onAppear { startPolling() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkScreenRecording()
        }
    }

    private func startPolling() {
        checkScreenRecording()
        // Poll every 2s for permission changes
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in checkScreenRecording() }
        }
    }

    private func checkScreenRecording() {
        Task {
            if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
               !content.displays.isEmpty {
                if !screenRecordingGranted {
                    screenRecordingGranted = true
                    SoundPlayer.shared.play("permission_granted")
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isGranted ? .green : iconColor)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isGranted)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 22))
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button("Grant") { onGrant() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isGranted ? Color.green.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isGranted)
    }
}

// MARK: - NotchMiniPreview (animated loop for Welcome screen)

struct NotchMiniPreview: View {
    @State private var phase = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
                            .frame(height: 24)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.black)
                            .frame(width: phase >= 2 ? 160 : 60, height: phase >= 2 ? 44 : 20)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: phase)
                    }
                    .frame(height: 44)

                    Spacer()

                    Text(phaseLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                        .animation(.easeInOut(duration: 0.2), value: phase)
                }
            }
            .onAppear { startLoop() }
    }

    var phaseLabel: String {
        switch phase {
        case 0: return "Press \u{2303}\u{21E7}4 to capture"
        case 1: return "Screenshot captured"
        case 2: return "It appears in the notch"
        case 3: return "Drag it anywhere"
        default: return ""
        }
    }

    func startLoop() {
        let delays: [Double] = [0, 1.2, 2.0, 3.0]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { phase = i }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            phase = 0
            startLoop()
        }
    }
}

// MARK: - Tutorial Card (kept for compatibility)

struct TutorialCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(description).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchController?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock if configured
        if !AppState.shared.settings.showInDock {
            NSApp.setActivationPolicy(.accessory)
        }

        // Initialize defaults
        if UserDefaults.standard.object(forKey: "hapticFeedback") == nil {
            UserDefaults.standard.set(true, forKey: "hapticFeedback")
        }
        if UserDefaults.standard.object(forKey: "soundEffectsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "soundEffectsEnabled")
        }

        // Show onboarding if not completed
        let onboardingVersion = UserDefaults.standard.integer(forKey: "onboardingVersion")
        if onboardingVersion < 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingWindowController.show()
            }
        }

        // Setup hotkey manager
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.start()

        // Setup Caps Lock hotkey observers
        CaptureManager.shared.setupHotkeyObservers()

        // Pre-warm SCShareableContent cache — eliminates 1-3s delay on first capture
        CaptureManager.shared.warmContentCache()

        // Setup notch controller
        notchController = NotchController.shared
        notchController?.setup()

        // Start clipboard monitoring
        ClipboardMonitor.shared.startMonitoring()

        // Clear session on launch if configured
        if AppState.shared.settings.clearSessionOnLaunch {
            AppState.shared.clearSession()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
        ClipboardMonitor.shared.stopMonitoring()
        TempFileManager.shared.cleanupAll()
    }

    // MARK: - Settings & Quit actions (called from menu and notifications)

    @objc func openSettingsAction() {
        NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main App

@main
struct NotchSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Hidden window — needed to give context to openSettings() in accessory apps
        Window("Hidden", id: "hidden") {
            HiddenContextView()
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topLeading)
        .windowStyle(.hiddenTitleBar)

        // Menu bar icon removed — actions are available via keyboard shortcuts
        // and the notch UI, so the status-bar badge was redundant.

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - HiddenContextView — Receives notification and opens Settings

@available(macOS 14.0, *)
struct HiddenContextView14: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    try? await Task.sleep(for: .milliseconds(200))
                    NSApp.windows.first { $0.title.contains("Settings") || $0.title.contains("Preferences") }?
                        .makeKeyAndOrderFront(nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                if !AppState.shared.settings.showInDock {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }
}

struct HiddenContextView13: View {
    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    try? await Task.sleep(for: .milliseconds(200))
                    NSApp.windows.first { $0.title.contains("Settings") || $0.title.contains("Preferences") }?
                        .makeKeyAndOrderFront(nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                if !AppState.shared.settings.showInDock {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }
}

struct HiddenContextView: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            HiddenContextView14()
        } else {
            HiddenContextView13()
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            Text("NotchSnap")
                .font(.headline)

            Divider()

            Button("Cattura Area ⌃⇧4") {
                Task { await CaptureManager.shared.startCapture(mode: .area) }
            }

            Button("Cattura Finestra ⌃⇧2") {
                Task { await CaptureManager.shared.startCapture(mode: .window) }
            }

            Button("Cattura Schermo ⌃⇧3") {
                Task { await CaptureManager.shared.startCapture(mode: .fullscreen) }
            }

            Button("Area + Editor ⌃⇧5") {
                NotificationCenter.default.post(name: .captureAreaWithEditor, object: nil)
            }

            Divider()

            Text("\(appState.screenshots.count) screenshot in sessione")
                .font(.caption)
                .foregroundColor(.secondary)

            if !appState.screenshots.isEmpty {
                Button("Cancella sessione") {
                    appState.clearSession()
                }
            }

            Divider()

            Button("Impostazioni…") {
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Esci da NotchSnap") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
    }
}

// MARK: - Menu Bar Icon with Badge

struct MenuBarIconView: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "camera.viewfinder")

            if count > 0 {
                Text(count > 9 ? "9+" : "\(count)")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.58, blue: 0.0)) // Orange #FF9500
                    )
                    .offset(x: 6, y: -4)
            }
        }
    }
}

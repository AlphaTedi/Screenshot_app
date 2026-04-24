import SwiftUI
import ServiceManagement

// MARK: - Settings View — Toolbar-tab style (like NotchNook / CleanShot X)

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            NotchAppearanceSettingsView()
                .tabItem {
                    Label("Notch", systemImage: "macbook")
                }

            CaptureSettingsView()
                .tabItem {
                    Label("Capture", systemImage: "camera.viewfinder")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 520, minHeight: 500)
        .environmentObject(appState)
        .onDisappear {
            NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
        }
    }
}

// MARK: - Helper: binding to AppSettings

@MainActor
private func settingsBinding<T>(_ appState: AppState, _ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
    Binding(
        get: { appState.settings[keyPath: keyPath] },
        set: { newValue in
            var settings = appState.settings
            settings[keyPath: keyPath] = newValue
            appState.updateSettings { $0 = settings }
        }
    )
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: { newValue in
                        appState.updateSettings { $0.launchAtLogin = newValue }
                        if #available(macOS 13.0, *) {
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("[Settings] Login item error: \(error)")
                            }
                        }
                    }
                ))

                Toggle("Show in Dock", isOn: Binding(
                    get: { appState.settings.showInDock },
                    set: { newValue in
                        appState.updateSettings { $0.showInDock = newValue }
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
                ))
            }

            Section("Feedback") {
                Toggle("Capture sound", isOn: settingsBinding(appState, \.playSound))
                Toggle("Interface sound effects", isOn: Binding(
                    get: {
                        UserDefaults.standard.object(forKey: "soundEffectsEnabled") == nil
                        || UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
                    },
                    set: { UserDefaults.standard.set($0, forKey: "soundEffectsEnabled") }
                ))
                Toggle("Haptic feedback (trackpad)", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "hapticFeedback") },
                    set: { UserDefaults.standard.set($0, forKey: "hapticFeedback") }
                ))
            }

            Section("Behavior") {
                Toggle("Automatically copy to clipboard", isOn: settingsBinding(appState, \.autoCopyToClipboard))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notch Appearance Settings (with live preview)

struct NotchAppearanceSettingsView: View {
    @AppStorage("notchCornerRadius")   private var cornerRadius: Double = 10
    @AppStorage("notchExpandedWidth")  private var expandedWidth: Double = 600
    @AppStorage("notchExpandedHeight") private var expandedHeight: Double = 180
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            // LIVE PREVIEW — updates in real-time while moving sliders
            Section {
                NotchLivePreview(
                    cornerRadius: cornerRadius,
                    width: expandedWidth,
                    height: expandedHeight
                )
                .frame(height: 140)
            } header: {
                Text("Preview")
            }

            // GEOMETRY
            Section("Geometry") {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Width")
                        Spacer()
                        Text("\(Int(expandedWidth))pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $expandedWidth, in: 400...800, step: 10)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Height")
                        Spacer()
                        Text("\(Int(expandedHeight))pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $expandedHeight, in: 120...280, step: 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Corner radius")
                        Spacer()
                        Text("\(Int(cornerRadius))pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $cornerRadius, in: 4...24, step: 1)
                }
            }

            // ACTIVATION
            Section("Activation") {
                Picker("Open the notch with", selection: settingsBinding(appState, \.notchTrigger)) {
                    Text("Cursor hover").tag(NotchTrigger.hover)
                    Text("Click").tag(NotchTrigger.click)
                    Text("Never (menu bar only)").tag(NotchTrigger.never)
                }

                if appState.settings.notchTrigger == .hover {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Hover delay")
                            Spacer()
                            Text(appState.settings.hoverDelayMs == 0 ? "Instant" : "\(appState.settings.hoverDelayMs)ms")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(appState.settings.hoverDelayMs) },
                                set: { newVal in appState.updateSettings { s in s.hoverDelayMs = Int(newVal) } }
                            ),
                            in: 0...500,
                            step: 25
                        )
                    }
                }
            }

            // BEHAVIOR
            Section("Behavior") {
                Picker("Auto-close after", selection: settingsBinding(appState, \.autoCollapseSeconds)) {
                    Text("3 seconds").tag(Optional(3))
                    Text("5 seconds").tag(Optional(5))
                    Text("10 seconds").tag(Optional(10))
                    Text("Never").tag(Optional<Int>.none)
                }

                Toggle("Show counter badge", isOn: settingsBinding(appState, \.showBadgeCounter))
            }

            // RESET
            Section {
                Button("Restore defaults") {
                    cornerRadius = 10
                    expandedWidth = 600
                    expandedHeight = 180
                    appState.updateSettings { s in
                        s.notchTrigger = .hover
                        s.hoverDelayMs = 0
                        s.autoCollapseSeconds = 5
                        s.showBadgeCounter = true
                    }
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Capture Settings

struct CaptureSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Capture") {
                Picker("Default mode", selection: settingsBinding(appState, \.defaultCaptureMode)) {
                    Text("Area").tag(CaptureMode.area)
                    Text("Window").tag(CaptureMode.window)
                    Text("Full screen").tag(CaptureMode.fullscreen)
                }

                Toggle("Screenshot sound", isOn: settingsBinding(appState, \.playSound))
                Toggle("Window shadow", isOn: settingsBinding(appState, \.windowShadow))
            }

            Section("Saving") {
                Toggle("Automatically save to file", isOn: settingsBinding(appState, \.autoSaveFile))

                if appState.settings.autoSaveFile {
                    HStack {
                        Text(appState.settings.saveDirectory.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose\u{2026}") { chooseSaveDirectory() }
                    }
                }

                Picker("File format", selection: settingsBinding(appState, \.fileFormat)) {
                    Text("PNG").tag(FileFormat.png)
                    Text("JPEG").tag(FileFormat.jpeg)
                }

                if appState.settings.fileFormat == .jpeg {
                    HStack {
                        Text("JPEG quality:")
                        Slider(value: settingsBinding(appState, \.jpegQuality), in: 0.1...1.0, step: 0.05)
                        Text("\(Int(appState.settings.jpegQuality * 100))%")
                            .frame(width: 40)
                    }
                }
            }

            Section("Session") {
                Picker("Screenshots in memory", selection: settingsBinding(appState, \.maxSessionScreenshots)) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                }

                Toggle("Clear session on launch", isOn: settingsBinding(appState, \.clearSessionOnLaunch))
            }
        }
        .formStyle(.grouped)
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            appState.updateSettings { $0.saveDirectory = url }
        }
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Active shortcuts") {
                ShortcutRow(label: "Capture area", keys: "\u{2303}\u{21E7}4")
                ShortcutRow(label: "Capture window", keys: "\u{2303}\u{21E7}2")
                ShortcutRow(label: "Capture screen", keys: "\u{2303}\u{21E7}3")
                ShortcutRow(label: "Capture area + Editor", keys: "\u{2303}\u{21E7}5")
                ShortcutRow(label: "Repeat last capture", keys: "\u{2303}\u{21E7}Space")
            }

            Section("General") {
                ShortcutRow(label: "Open Settings", keys: "\u{2318} ,")
                ShortcutRow(label: "Quit app", keys: "\u{2318} Q")
            }

            Section {
                Text("Shortcuts using \u{2303}\u{21E7} (Control+Shift) work globally from any app.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let label: String
    let keys: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(5)
        }
    }
}

// MARK: - About

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("NotchSnap")
                .font(.title)
                .fontWeight(.bold)

            Text("v1.0")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Screenshot tool that lives in your Mac's notch.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("\u{00A9} 2026 NotchSnap")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

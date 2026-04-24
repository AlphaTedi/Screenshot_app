import SwiftUI
import ServiceManagement

// MARK: - Settings View — Toolbar-tab style (like NotchNook / CleanShot X)

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Generali", systemImage: "gearshape")
                }

            NotchAppearanceSettingsView()
                .tabItem {
                    Label("Notch", systemImage: "macbook")
                }

            CaptureSettingsView()
                .tabItem {
                    Label("Cattura", systemImage: "camera.viewfinder")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Scorciatoie", systemImage: "keyboard")
                }

            AboutSettingsView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
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
            Section("Avvio") {
                Toggle("Apri al login", isOn: Binding(
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

                Toggle("Mostra nel Dock", isOn: Binding(
                    get: { appState.settings.showInDock },
                    set: { newValue in
                        appState.updateSettings { $0.showInDock = newValue }
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
                ))
            }

            Section("Feedback") {
                Toggle("Suono alla cattura", isOn: settingsBinding(appState, \.playSound))
                Toggle("Effetti sonori interfaccia", isOn: Binding(
                    get: {
                        UserDefaults.standard.object(forKey: "soundEffectsEnabled") == nil
                        || UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
                    },
                    set: { UserDefaults.standard.set($0, forKey: "soundEffectsEnabled") }
                ))
                Toggle("Feedback aptico (trackpad)", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "hapticFeedback") },
                    set: { UserDefaults.standard.set($0, forKey: "hapticFeedback") }
                ))
            }

            Section("Comportamento") {
                Toggle("Copia automaticamente in clipboard", isOn: settingsBinding(appState, \.autoCopyToClipboard))
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
                Text("Anteprima")
            }

            // GEOMETRY
            Section("Geometria") {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Larghezza")
                        Spacer()
                        Text("\(Int(expandedWidth))pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $expandedWidth, in: 400...800, step: 10)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Altezza")
                        Spacer()
                        Text("\(Int(expandedHeight))pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $expandedHeight, in: 120...280, step: 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Raggio angoli")
                        Spacer()
                        Text("\(Int(cornerRadius))pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $cornerRadius, in: 4...24, step: 1)
                }
            }

            // ACTIVATION
            Section("Attivazione") {
                Picker("Apri la notch con", selection: settingsBinding(appState, \.notchTrigger)) {
                    Text("Hover del cursore").tag(NotchTrigger.hover)
                    Text("Click").tag(NotchTrigger.click)
                    Text("Mai (solo menu bar)").tag(NotchTrigger.never)
                }

                if appState.settings.notchTrigger == .hover {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Delay hover")
                            Spacer()
                            Text(appState.settings.hoverDelayMs == 0 ? "Istantaneo" : "\(appState.settings.hoverDelayMs)ms")
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
            Section("Comportamento") {
                Picker("Chiudi automaticamente dopo", selection: settingsBinding(appState, \.autoCollapseSeconds)) {
                    Text("3 secondi").tag(Optional(3))
                    Text("5 secondi").tag(Optional(5))
                    Text("10 secondi").tag(Optional(10))
                    Text("Mai").tag(Optional<Int>.none)
                }

                Toggle("Mostra badge contatore", isOn: settingsBinding(appState, \.showBadgeCounter))
            }

            // RESET
            Section {
                Button("Ripristina valori predefiniti") {
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
            Section("Cattura") {
                Picker("Modalita' predefinita", selection: settingsBinding(appState, \.defaultCaptureMode)) {
                    Text("Area").tag(CaptureMode.area)
                    Text("Finestra").tag(CaptureMode.window)
                    Text("Schermo intero").tag(CaptureMode.fullscreen)
                }

                Toggle("Suono screenshot", isOn: settingsBinding(appState, \.playSound))
                Toggle("Ombra finestra", isOn: settingsBinding(appState, \.windowShadow))
            }

            Section("Salvataggio") {
                Toggle("Salva automaticamente su file", isOn: settingsBinding(appState, \.autoSaveFile))

                if appState.settings.autoSaveFile {
                    HStack {
                        Text(appState.settings.saveDirectory.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Scegli\u{2026}") { chooseSaveDirectory() }
                    }
                }

                Picker("Formato file", selection: settingsBinding(appState, \.fileFormat)) {
                    Text("PNG").tag(FileFormat.png)
                    Text("JPEG").tag(FileFormat.jpeg)
                }

                if appState.settings.fileFormat == .jpeg {
                    HStack {
                        Text("Qualita' JPEG:")
                        Slider(value: settingsBinding(appState, \.jpegQuality), in: 0.1...1.0, step: 0.05)
                        Text("\(Int(appState.settings.jpegQuality * 100))%")
                            .frame(width: 40)
                    }
                }
            }

            Section("Sessione") {
                Picker("Screenshot in memoria", selection: settingsBinding(appState, \.maxSessionScreenshots)) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                }

                Toggle("Cancella sessione all'avvio", isOn: settingsBinding(appState, \.clearSessionOnLaunch))
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
            Section("Scorciatoie attive") {
                ShortcutRow(label: "Cattura area", keys: "\u{2303}\u{21E7}4")
                ShortcutRow(label: "Cattura finestra", keys: "\u{2303}\u{21E7}2")
                ShortcutRow(label: "Cattura schermo", keys: "\u{2303}\u{21E7}3")
                ShortcutRow(label: "Cattura area + Editor", keys: "\u{2303}\u{21E7}5")
                ShortcutRow(label: "Ripeti ultima cattura", keys: "\u{2303}\u{21E7}Spazio")
            }

            Section("Generali") {
                ShortcutRow(label: "Apri Settings", keys: "\u{2318} ,")
                ShortcutRow(label: "Chiudi app", keys: "\u{2318} Q")
            }

            Section {
                Text("Le scorciatoie con \u{2303}\u{21E7} (Control+Shift) funzionano globalmente da qualsiasi app.")
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

            Text("Screenshot tool che vive nella notch del tuo Mac.")
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

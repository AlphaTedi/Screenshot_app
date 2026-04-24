import Foundation
import AppKit

// MARK: - Enums

enum NotchTrigger: String, Codable, CaseIterable {
    case hover
    case click
    case never
}

enum FileFormat: String, Codable, CaseIterable {
    case png
    case jpeg
}

enum CaptureMode: String, Codable, CaseIterable {
    case area
    case window
    case fullscreen
}

// MARK: - KeyCombo

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: CGEventFlags

    enum CodingKeys: String, CodingKey {
        case keyCode, modifierRaw
    }

    init(keyCode: UInt16, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let raw = try container.decode(UInt64.self, forKey: .modifierRaw)
        modifiers = CGEventFlags(rawValue: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifierRaw)
    }

    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers.rawValue == rhs.modifiers.rawValue
    }
}

// MARK: - AppSettings

struct AppSettings: Codable {
    // Hotkeys (Cmd+Shift+1/2/3/Space)
    var captureHotkey = KeyCombo(keyCode: 18, modifiers: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))
    var windowHotkey = KeyCombo(keyCode: 19, modifiers: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))
    var fullscreenHotkey = KeyCombo(keyCode: 20, modifiers: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))
    var repeatHotkey = KeyCombo(keyCode: 49, modifiers: CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))

    // Capture
    var defaultCaptureMode: CaptureMode = .area
    var playSound: Bool = true
    var windowShadow: Bool = false

    // Notch
    var notchTrigger: NotchTrigger = .hover
    var hoverDelayMs: Int = 0
    var autoCollapseSeconds: Int? = 5
    var showBadgeCounter: Bool = true

    // Save
    var autoCopyToClipboard: Bool = true
    var autoSaveFile: Bool = false
    var saveDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/NotchSnap")
    var fileFormat: FileFormat = .png
    var jpegQuality: Double = 0.85

    // Gallery
    var maxSessionScreenshots: Int = 20
    var clearSessionOnLaunch: Bool = false

    // General
    var launchAtLogin: Bool = false
    var showInDock: Bool = false

    // MARK: Persistence

    private static let storageKey = "notchsnap.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

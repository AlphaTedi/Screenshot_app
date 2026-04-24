import AppKit

// MARK: - SoundManager — Replaces SoundPlayer with simpler NSSound approach
//
// Custom AIFF files go in Resources/Sounds/ (AIFF, 16-bit, 44.1kHz, mono).
// Falls back to macOS system sounds during development.

final class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()

    private var cache: [SoundName: NSSound] = [:]

    private init() {
        // Pre-load custom sounds from bundle
        for name in SoundName.allCases {
            if let url = Bundle.main.url(forResource: name.rawValue, withExtension: "aiff"),
               let sound = NSSound(contentsOf: url, byReference: false) {
                cache[name] = sound
            }
        }
    }

    private var isUserEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEffectsEnabled") == nil
            || UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
    }

    func play(_ name: SoundName) {
        guard isUserEnabled else { return }

        let vol = name.volume

        // Try cached custom sound first (copy for concurrent playback)
        if let cached = cache[name], let sound = cached.copy() as? NSSound {
            sound.volume = vol
            sound.play()
            return
        }

        // Fallback to system sound
        if let fallback = name.systemFallback {
            fallback.volume = vol
            fallback.play()
        }
    }

    // MARK: - Sound Names

    enum SoundName: String, CaseIterable {
        case capture   = "notchsnap_capture"
        case expand    = "notchsnap_expand"
        case collapse  = "notchsnap_collapse"
        case copy      = "notchsnap_copy"
        case delete    = "notchsnap_delete"
        case clipboard = "notchsnap_clipboard"

        var volume: Float {
            switch self {
            case .capture:   return 0.30
            case .expand:    return 0.18
            case .collapse:  return 0.14
            case .copy:      return 0.25
            case .delete:    return 0.20
            case .clipboard: return 0.15
            }
        }

        // macOS system sounds as fallback while custom AIFFs are not yet created
        // Ref: /System/Library/Sounds/
        var systemFallback: NSSound? {
            switch self {
            case .capture:   return NSSound(named: "Tink")
            case .expand:    return NSSound(named: "Pop")
            case .collapse:  return NSSound(named: "Pop")
            case .copy:      return NSSound(named: "Morse")
            case .delete:    return NSSound(named: "Sosumi")
            case .clipboard: return NSSound(named: "Tink")
            }
        }
    }
}

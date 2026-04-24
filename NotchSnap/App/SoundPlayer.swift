import AppKit

// MARK: - SoundPlayer — Premium minimal sound effects
//
// Custom AIFF files: sine/triangle waveforms, 40-180ms, soft attack,
// 800-4000Hz, subtle reverb. Falls back to system sounds if missing.
// Respects both system sound prefs and user's in-app toggle.

final class SoundPlayer: @unchecked Sendable {
    static let shared = SoundPlayer()

    // Fallback: event name → system sound (only used if custom AIFF missing)
    private let systemSoundMap: [String: String] = [
        "screenshot_capture": "Tink",
        "notch_expand":       "Tink",
        "notch_collapse":     "Tink",
        "copy_confirm":       "Tink",
        "permission_granted": "Glass",
        "step_advance":       "Tink",
        "onboarding_complete":"Glass",
        "item_delete":        "Tink",
    ]

    // Volume per event — custom AIFFs are already normalized,
    // so these control final loudness. Keep subtle.
    private let volumes: [String: Float] = [
        "screenshot_capture": 0.35,
        "notch_expand":       0.20,
        "notch_collapse":     0.18,
        "copy_confirm":       0.30,
        "permission_granted": 0.35,
        "step_advance":       0.22,
        "onboarding_complete":0.40,
        "item_delete":        0.25,
    ]

    // Cache loaded sounds for instant playback
    private var cache: [String: NSSound] = [:]

    private init() {
        // Pre-load all custom sounds into cache
        for name in systemSoundMap.keys {
            if let url = Bundle.main.url(forResource: name, withExtension: "aiff"),
               let sound = NSSound(contentsOf: url, byReference: false) {
                cache[name] = sound
            }
        }
    }

    func play(_ name: String) {
        // Respect user's in-app toggle
        guard UserDefaults.standard.object(forKey: "soundEffectsEnabled") == nil
              || UserDefaults.standard.bool(forKey: "soundEffectsEnabled") else { return }

        let vol = volumes[name] ?? 0.20

        // Use cached custom AIFF (copy for concurrent playback)
        if let cached = cache[name], let sound = cached.copy() as? NSSound {
            sound.volume = vol
            sound.play()
            return
        }

        // Fallback: try loading from bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.volume = vol
            sound.play()
        } else if let sysName = systemSoundMap[name],
                  let sound = NSSound(named: NSSound.Name(sysName)) {
            sound.volume = vol
            sound.play()
        }
    }
}

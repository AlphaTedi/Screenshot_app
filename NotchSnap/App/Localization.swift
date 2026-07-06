import Foundation

// MARK: - L10n — lightweight in-app localization
//
// Default: follow the Mac's system language (like the theme follows the
// system appearance). The user can override in Settings → General.
// Kept as simple dictionaries — no .lproj plumbing — so adding a language
// is one table.

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case italian = "it"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:  return L10n.t("lang.system")
        case .english: return "English"
        case .italian: return "Italiano"
        }
    }
}

enum L10n {
    static let storageKey = "appLanguage"

    /// Effective 2-letter code: user override, else the system language.
    static var languageCode: String {
        let pref = UserDefaults.standard.string(forKey: storageKey) ?? "system"
        if pref != "system" { return pref }
        let sys = Locale.preferredLanguages.first ?? "en"
        return String(sys.prefix(2))
    }

    static var locale: Locale { Locale(identifier: languageCode) }

    static func t(_ key: String) -> String {
        if languageCode == "it", let s = it[key] { return s }
        return en[key] ?? key
    }

    /// System-style relative timestamp ("2 min ago" / "2 min fa") in the
    /// effective language.
    static func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return t("time.now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Tables

    private static let en: [String: String] = [
        "lang.system": "System default",
        "time.now": "now",
        // Filters
        "filter.all": "All",
        "filter.tray": "Tray",
        "filter.shots": "Shots",
        "filter.snippets": "Snippets",
        "filter.links": "Links",
        "filter.text": "Text",
        "tray.clear": "Clear",
        // Notch
        "notch.empty": "No content yet.\nTake a screenshot, copy something, or drop a file.",
        "tray.empty": "Drop files here, drag them out anywhere",
        "tile.quickCopy": "Quick Copy",
        "tile.copied": "\u{2713} Copied",
        // Actions
        "action.copy": "Copy",
        "action.pin": "Pin",
        "action.unpin": "Unpin",
        "action.delete": "Delete",
        "action.remove": "Remove",
        "action.edit": "Edit\u{2026}",
        "action.moveLeft": "Move Left",
        "action.moveRight": "Move Right",
        "action.save": "Save\u{2026}",
        // Snippets
        "snippet.new": "New Snippet",
        "snippet.editTitle": "Edit Snippet",
        "snippet.newTitle": "New Snippet",
        "snippet.labelPlaceholder": "Label (e.g. Email sign-off)",
        "snippet.create": "Create",
        "snippet.saveButton": "Save",
        "snippet.cancel": "Cancel",
        // Settings
        "settings.language": "Language",
        "settings.language.subtitle": "Follows your Mac's language by default.",
    ]

    private static let it: [String: String] = [
        "lang.system": "Predefinita di sistema",
        "time.now": "ora",
        "filter.all": "Tutti",
        "filter.tray": "Vassoio",
        "filter.shots": "Scatti",
        "filter.snippets": "Snippet",
        "filter.links": "Link",
        "filter.text": "Testo",
        "tray.clear": "Svuota",
        "notch.empty": "Ancora niente qui.\nFai uno screenshot, copia qualcosa o trascina un file.",
        "tray.empty": "Trascina i file qui, portali fuori dove vuoi",
        "tile.quickCopy": "Copia rapida",
        "tile.copied": "\u{2713} Copiato",
        "action.copy": "Copia",
        "action.pin": "Fissa",
        "action.unpin": "Sblocca",
        "action.delete": "Elimina",
        "action.remove": "Rimuovi",
        "action.edit": "Modifica\u{2026}",
        "action.moveLeft": "Sposta a sinistra",
        "action.moveRight": "Sposta a destra",
        "action.save": "Salva\u{2026}",
        "snippet.new": "Nuovo snippet",
        "snippet.editTitle": "Modifica snippet",
        "snippet.newTitle": "Nuovo snippet",
        "snippet.labelPlaceholder": "Etichetta (es. Firma email)",
        "snippet.create": "Crea",
        "snippet.saveButton": "Salva",
        "snippet.cancel": "Annulla",
        "settings.language": "Language",
        "settings.language.subtitle": "Segue la lingua del Mac per impostazione predefinita.",
    ]
}

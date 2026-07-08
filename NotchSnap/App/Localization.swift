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
        "menu.clearTray": "Clear Tray",
        "menu.clearShots": "Remove All Screenshots",
        "menu.clearHistory": "Clear Clipboard History",
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
        // Notes
        "filter.notes": "Notes",
        "filter.todos": "To-dos",
        "notes.placeholder": "Jot something down\u{2026}",
        "notes.makeReminder": "Make reminder",
        "notes.saveNote": "Save note (\u{2318}\u{21A9})",
        "notes.saveReminder": "Create reminder (\u{2318}\u{21A9})",
        "notes.saveButtonNote": "Save",
        "notes.saveButtonReminder": "Remind",
        "notes.emptyList": "Notes and reminders you add appear here.",
        "notes.remindersDenied": "Reminders access is off. Allow it in System Settings to sync with Apple Reminders.",
        "notes.openSettings": "Open System Settings",
        // To-dos
        "urgency.low": "Low",
        "urgency.medium": "Medium",
        "urgency.high": "High",
        "todo.completed": "Completed",
        "todo.empty": "Nothing here yet. \u{2325}Space to add a to-do.",
        "todo.emptyToday": "Nothing due today.",
        "todo.newTodo": "New to-do",
        "todo.titlePlaceholder": "What needs doing?",
        "todo.create": "Create",
        "todo.noCollection": "No collection",
        "todo.newCollection": "New collection",
        "todo.collectionName": "Collection name",
        "todo.moveTo": "Move to\u{2026}",
        "todo.searchCollections": "Search collections\u{2026}",
        "todo.shortcuts": "Keyboard shortcuts",
        "todo.sc.quickEntry": "Quick entry (from anywhere)",
        "todo.sc.newTodo": "New to-do (in app)",
        "todo.sc.switchCollection": "Switch collection",
        "todo.sc.moveFocus": "Move between to-dos",
        "todo.sc.toggleComplete": "Complete / uncomplete",
        "todo.sc.moveItem": "Move to another collection",
        "todo.sc.cycleCollection": "Cycle collection (creating)",
        "todo.sc.cycleUrgency": "Cycle urgency (creating)",
        "todo.sc.create": "Create the to-do",
        "todo.sc.cancel": "Cancel / close",
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
        "menu.clearTray": "Svuota il vassoio",
        "menu.clearShots": "Rimuovi tutti gli screenshot",
        "menu.clearHistory": "Svuota cronologia appunti",
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
        "filter.notes": "Note",
        "filter.todos": "To-do",
        "notes.placeholder": "Scrivi qualcosa\u{2026}",
        "notes.makeReminder": "Crea promemoria",
        "notes.saveNote": "Salva nota (\u{2318}\u{21A9})",
        "notes.saveReminder": "Crea promemoria (\u{2318}\u{21A9})",
        "notes.saveButtonNote": "Salva",
        "notes.saveButtonReminder": "Ricorda",
        "notes.emptyList": "Le note e i promemoria che aggiungi appaiono qui.",
        "notes.remindersDenied": "L'accesso ai Promemoria \u{00E8} disattivato. Consentilo nelle Impostazioni di Sistema per sincronizzare con Promemoria.",
        "notes.openSettings": "Apri Impostazioni di Sistema",
        "urgency.low": "Bassa",
        "urgency.medium": "Media",
        "urgency.high": "Alta",
        "todo.completed": "Completati",
        "todo.empty": "Ancora niente. \u{2325}Spazio per aggiungere.",
        "todo.emptyToday": "Niente in scadenza oggi.",
        "todo.newTodo": "Nuovo to-do",
        "todo.titlePlaceholder": "Cosa c'\u{00E8} da fare?",
        "todo.create": "Crea",
        "todo.noCollection": "Nessuna raccolta",
        "todo.newCollection": "Nuova raccolta",
        "todo.collectionName": "Nome della raccolta",
        "todo.moveTo": "Sposta in\u{2026}",
        "todo.searchCollections": "Cerca raccolte\u{2026}",
        "todo.shortcuts": "Scorciatoie da tastiera",
        "todo.sc.quickEntry": "Inserimento rapido (ovunque)",
        "todo.sc.newTodo": "Nuovo to-do (nell'app)",
        "todo.sc.switchCollection": "Cambia raccolta",
        "todo.sc.moveFocus": "Naviga tra i to-do",
        "todo.sc.toggleComplete": "Completa / annulla",
        "todo.sc.moveItem": "Sposta in un'altra raccolta",
        "todo.sc.cycleCollection": "Cambia raccolta (creazione)",
        "todo.sc.cycleUrgency": "Cambia urgenza (creazione)",
        "todo.sc.create": "Crea il to-do",
        "todo.sc.cancel": "Annulla / chiudi",
        "settings.language": "Language",
        "settings.language.subtitle": "Segue la lingua del Mac per impostazione predefinita.",
    ]
}

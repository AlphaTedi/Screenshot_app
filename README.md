# NotchSnap

Un'app macOS che sfrutta il notch dei MacBook per screenshot e funzioni rapide.

## Requisiti

- macOS 13.0 o superiore
- (Per sviluppo) Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Installazione (utenti)

1. Vai nella sezione [Releases](../../releases) del repository.
2. Scarica l'ultimo file `NotchSnap.dmg` (o `NotchSnap.zip`).
3. Apri il `.dmg` e trascina `NotchSnap.app` nella cartella **Applicazioni**.
4. Alla prima apertura, se macOS mostra "app non verificata":
   - Tasto destro su `NotchSnap.app` → **Apri** → conferma.
   - Oppure: Impostazioni di Sistema → Privacy e Sicurezza → **Apri comunque**.

> L'app non è firmata con Apple Developer ID, quindi macOS mostra un avviso la prima volta. Questo è normale.

## Build dal codice

```bash
# Genera il progetto Xcode (se modifichi project.yml)
xcodegen generate

# Apri in Xcode
open NotchSnap.xcodeproj

# Oppure build da command line
xcodebuild -project NotchSnap.xcodeproj -scheme NotchSnap -configuration Release
```

## Release automatiche

Ogni push di un tag `v*` (es. `v1.0.0`) attiva GitHub Actions che builda l'app e pubblica una Release con il `.zip` pronto da scaricare.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Licenza

MIT

# NotchSnap

A macOS app that leverages the MacBook notch for screenshots and quick actions.

## Requirements

- macOS 13.0 or later
- (For development) Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Installation (users)

1. Go to the [Releases](../../releases) section of this repository.
2. Download the latest `NotchSnap.zip` (or `.dmg`).
3. Unzip and drag `NotchSnap.app` into your **Applications** folder.
4. On first launch, if macOS shows "app is not verified":
   - Right-click `NotchSnap.app` → **Open** → confirm.
   - Or: System Settings → Privacy & Security → **Open Anyway**.

> The app is not signed with an Apple Developer ID, so macOS will show a warning on first launch. This is expected.

## Build from source

```bash
# Generate the Xcode project (if you modified project.yml)
xcodegen generate

# Open in Xcode
open NotchSnap.xcodeproj

# Or build from the command line
xcodebuild -project NotchSnap.xcodeproj -scheme NotchSnap -configuration Release
```

## Automated releases

Pushing a tag matching `v*` (e.g. `v1.0.0`) triggers a GitHub Actions workflow that builds the app and publishes a Release with a ready-to-download `.zip`.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

MIT

# Repository Guidelines

## Project Structure & Module Organization

This repository is a Swift Package Manager project for a macOS menu bar utility.

- `Package.swift`: SwiftPM package definition.
- `Sources/MouseBack/MouseBack.swift`: application entry point, AppKit menu, permission checks, event taps, and key remapping logic.
- `scripts/package-app.sh`: builds a release binary and packages `dist/MouseBack.app`.
- `scripts/reset-permissions.sh`: resets macOS TCC entries for the app bundle identifier.
- `README.md`: user-facing run and permission notes.

Generated output such as `.build/`, `dist/`, and local logs should not be treated as source.

## Build, Test, and Development Commands

Use these commands from the repository root:

```sh
swift build
```

Builds the debug SwiftPM executable and verifies source compilation.

```sh
swift run MouseBack
```

Runs the tool directly from SwiftPM. Useful for quick checks, but macOS permissions may bind to the terminal or debug executable.

```sh
scripts/package-app.sh
open -n dist/MouseBack.app
```

Builds and launches the normal menu bar app. Repackaging changes the ad-hoc signature hash, so Accessibility permissions may need to be removed and re-added.

```sh
scripts/reset-permissions.sh
```

Clears stored Accessibility/Input Monitoring decisions for `local.mouseback.app`.

## Coding Style & Naming Conventions

Use Swift with 4-space indentation. Keep AppKit UI code and event-tap logic straightforward and localized unless a real abstraction reduces complexity. Prefer descriptive method names such as `startKeyboardEventTap()` and `requestInputMonitoringPermissionIfNeeded()`. Keep user-visible menu text in Chinese.

## Testing Guidelines

There is currently no test target. At minimum, run `swift build` after edits. For behavior changes, package and manually verify:

- menu shows `运行中`
- `辅助功能` and `输入监控` show `已授权`
- side buttons trigger browser/Finder back and forward

## Commit & Pull Request Guidelines

No Git history is present, so use concise imperative commit messages, for example `Localize menu labels` or `Split mouse and keyboard event taps`.

Pull requests should include:

- a short summary of behavior changes
- manual verification steps and results
- screenshots for menu or permission UI changes
- notes if users must re-add macOS permissions after packaging

## Security & Configuration Tips

Do not commit personal TCC database data, local logs, or generated app bundles. Be careful when changing `CFBundleIdentifier`; doing so invalidates existing macOS permissions.

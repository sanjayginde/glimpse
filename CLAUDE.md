# CLAUDE.md

Glimpse is a macOS menu bar app that shows a monthly calendar popup.
Targets macOS 13+, Swift 6 strict concurrency, zero external dependencies.

## Build & Development Commands

```bash
# Compile check (fast, no .app bundle)
swift build

# Clean build → produces "Glimpse.app"
./build-macos-app.sh

# Incremental build (skip clean, faster for dev)
./build-macos-app.sh --skip-clean

# Build and install to /Applications (required for SMAppService login item)
./build-macos-app.sh --install

# Build and install to ~/Applications (no sudo/admin needed)
./build-macos-app.sh --install-user

# Developer ID sign + notarize (needs "glimpse-notary" notarytool keychain profile)
SIGN_IDENTITY="Developer ID Application: …" ./build-macos-app.sh --notarize

# Run after building
open "Glimpse.app"
```

## Architecture

SwiftUI-native `MenuBarExtra` with `.window` style — no AppDelegate or NSStatusItem.
- `@main GlimpseApp` owns `DayProvider` (day-change observer) and the `MenuBarExtra` scene
- `CalendarView` is pure SwiftUI, self-contained state via `@State` / `@AppStorage`
- `MenuBarExtra.behavior = .window` — popup closes on outside click, stays open for internal clicks
- `LSUIElement = true` — no Dock icon

## Key Files

- `Sources/GlimpseApp.swift` — entry point, `DayProvider`, `MenuBarExtra` label
- `Sources/CalendarView.swift` — SwiftUI calendar grid, week-row computation, all settings via `@AppStorage`

## AppStorage Keys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `showWeekNumbers` | Bool | true | Week number column |
| `showDateInIcon` | Bool | true | Day number in menu bar icon |
| `firstWeekday` | Int | 1 | First day of week (1=Sun, 2=Mon, 7=Sat) |
| `alwaysDarkMode` | Bool | false | Force dark appearance for the popup |

## Concurrency

Swift 6 strict concurrency. `DayProvider` is `@MainActor`. Notification callbacks use `Task { @MainActor in ... }`.

## Gotchas

- `cal.firstWeekday` set explicitly in `buildWeekRows` — locale default may be Monday, breaking the Sun–Sat grid
- `SMAppService.mainApp.register()` silently fails when run outside `/Applications`; use `--install` flag for testing login item
- Day rollover uses `NSCalendarDayChanged` (plus wake as a backstop), not a `Timer` — a timer's countdown is thrown off by sleep, leaving a stale date after the Mac sleeps through midnight
- `.buttonStyle(.glass)` on nav buttons gated behind `#available(macOS 26, *)` — falls back to `.plain` on older systems
- Releases are built by `.github/workflows/release.yml` (pushes to `main` touching `Sources/`, `Resources/`, `Package.swift`); the `update-tap` job then bumps `Casks/glimpse.rb` in `sanjayginde/homebrew-tap` using the `HOMEBREW_TAP_TOKEN` secret
- CI signs + notarizes when `MACOS_CERT_P12` / `MACOS_CERT_PASSWORD` / `NOTARY_KEY_P8` / `NOTARY_KEY_ID` / `NOTARY_ISSUER` secrets exist; a partial set fails, and with none only PR builds fall back to ad-hoc (releases fail rather than ship un-notarized)
- Local builds with Command Line Tools fail (`SwiftUIMacros` plugin not found) — select full Xcode via `xcode-select`

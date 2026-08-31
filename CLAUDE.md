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

# Run after building
open "Glimpse.app"
```

## Architecture

SwiftUI-native `MenuBarExtra` with `.window` style — no AppDelegate or NSStatusItem.
- `@main GlimpseApp` owns `DayProvider` (midnight timer) and the `MenuBarExtra` scene
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
| `showRollingWeeks` | Bool | false | Toggle rolling 6-week view (vs. classic month grid) |

## Concurrency

Swift 6 strict concurrency. `DayProvider` is `@MainActor`. Timer callbacks use `Task { @MainActor in ... }`.

## Gotchas

- `cal.firstWeekday` set explicitly in `buildWeekRows` — locale default may be Monday, breaking the Sun–Sat grid
- `SMAppService.mainApp.register()` silently fails when run outside `/Applications`; use `--install` flag for testing login item
- Midnight timer uses a recursive one-shot pattern (not 24h repeating) to correctly handle DST transitions
- `.buttonStyle(.glass)` on nav buttons gated behind `#available(macOS 26, *)` — falls back to `.plain` on older systems

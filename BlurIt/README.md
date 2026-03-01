# BlurIt

A lightweight macOS menu bar app that applies a full-screen blur overlay across all active displays.

## Features

- **Blur toggle** — enable/disable from the menu bar or global keyboard shortcut (⌘⇧B default)
- **5 blur styles** — Standard, Frosted Glass, Soft Light, Darkened, Minimal
- **Adjustable intensity** — 0–100% slider, persisted between sessions
- **Text overlay** — optional centered text with font size, color picker, drop shadow, and pill background
- **Multi-monitor** — one overlay window per connected display
- **Click-through mode** — overlay visible but allows interaction beneath it
- **Launch at Login** — using macOS Login Items API
- **Preferences panel** — full configuration window

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Build Instructions

1. Open `BlurIt.xcodeproj` in Xcode 15+
2. Select the `BlurIt` scheme
3. Press `⌘R` to build and run

> **Note:** The global keyboard shortcut requires **Accessibility** permission.
> On first launch, macOS will prompt you: System Settings → Privacy & Security → Accessibility → enable BlurIt.

## Architecture

| File | Responsibility |
|---|---|
| `BlurItApp.swift` | App entry point, hides Dock icon |
| `SettingsManager.swift` | UserDefaults wrapper + `BlurStyle` enum |
| `MenuBarController.swift` | `NSStatusItem` and dropdown menu |
| `MenuViews.swift` | SwiftUI slider/text views hosted in menu |
| `OverlayManager.swift` | Creates/destroys overlay windows per screen |
| `OverlayWindow.swift` | `NSWindow` subclass — always-on-top, borderless |
| `BlurRenderer.swift` | `NSVisualEffectView` blur rendering |
| `TextOverlayRenderer.swift` | Centered text with shadow and pill background |
| `ShortcutManager.swift` | Global hotkey via `CGEventTap` |
| `LoginItemManager.swift` | Launch at login via `SMAppService` |
| `PreferencesView.swift` | SwiftUI preferences window |

## License

MIT

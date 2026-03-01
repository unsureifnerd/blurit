# BlurIt

> A lightweight macOS menu bar app that blankets your screen in beautiful blur effects — ideal for presentations, focus sessions, and privacy.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## Features

### Blur
- **9 blur styles** — Standard, Frosted Glass, Soft Light, Darkened, Minimal, Mosaic, Chessboard, Dot Matrix, Stripes
- **Intensity slider** — 10–100%, persisted between sessions
- **Animated toggle** — Instant / Fast / Medium / Slow fade presets
- **Multi-monitor** — one overlay per display, rebuilt automatically on connect/disconnect and after sleep/wake

### Clock overlay
- **8 clock styles** — Digital Modern, Digital Retro, Digital Bold, Neon, Fuzzy ("quarter past three"), Analog, Analog Minimal, Analog Arc
- 24-hour / 12-hour toggle

### Text overlay
- **5 text styles** — Plain, Neon Glow, Retro Terminal, Frosted Glass, Outlined
- Custom text, font size, colour picker, drop shadow, pill background

### Modes
| Mode | Behaviour |
|---|---|
| **Normal** | Blur covers everything at window level 100 |
| **Preview** | Auto-starts blur; Preferences floats above it (level 102) so you can tune settings live. Toggle off hides blur. |
| **Click-through** | Overlay passes all mouse events to apps beneath it |

### System
- **Global shortcut** — default ⌘⇧B, fully re-bindable in Preferences
- **Double-ESC** — exits blur from any app (requires Accessibility permission)
- **Exit button** — floating pill, 9 configurable positions or hidden
- **Launch at Login** — via `SMAppService`
- **No Dock icon** — pure menu bar app (`LSUIElement = true`)

---

## Screenshots

> _Coming soon_

---

## Download

Grab the latest **[BlurIt-1.0.dmg](BlurIt-1.0.dmg)**, open it, drag `BlurIt.app` into **Applications**.

> **First launch note:** Because the app is not yet notarized, macOS Gatekeeper will show a warning. Right-click (or Control-click) `BlurIt.app` → **Open** → **Open** to bypass it. This is a one-time step.

---

## Build from source

**Requirements:** Xcode 15+, macOS 13 SDK

```bash
git clone https://github.com/unsureifnerd/blurit.git
cd blurit/BlurIt
open BlurIt.xcodeproj   # then ⌘R
```

> **Accessibility permission** is required for the global shortcut and double-ESC.
> On first launch macOS will prompt you, or go to **System Settings → Privacy & Security → Accessibility → BlurIt**.

---

## Architecture

| File | Responsibility |
|---|---|
| `BlurItApp.swift` | `@main` entry, hides Dock icon via `NSApp.setActivationPolicy(.accessory)` |
| `SettingsManager.swift` | `UserDefaults` wrapper, `BlurStyle` / `ClockStyle` / `TextStyle` / `AnimationDuration` enums |
| `MenuBarController.swift` | `NSStatusItem` + minimal 4-item menu |
| `MenuViews.swift` | SwiftUI slider/text-field views hosted in NSMenu items |
| `OverlayManager.swift` | Creates, animates, and destroys one `OverlayWindow` per `NSScreen` |
| `OverlayWindow.swift` | Borderless `NSWindow` (level 100); handles fade-in/out via `NSAnimationContext` |
| `BlurRenderer.swift` | `NSVisualEffectView` + pattern overlay views (Mosaic, Chessboard, Dot Matrix, Stripes) |
| `ContentOverlayView.swift` | SwiftUI clock and text rendered on top of blur |
| `ExitButtonWindow.swift` | Always-interactive floating exit pill (level 101) |
| `ShortcutManager.swift` | `CGEventTap` global hotkey; recovers from `tapDisabledByTimeout` automatically |
| `LoginItemManager.swift` | `SMAppService` launch-at-login |
| `PreferencesView.swift` | Tabbed preferences window (Settings + About); floats above blur at level 102 |

**Window level stack:**

```
102  Preferences window      ← always reachable
101  Exit button             ← always clickable
100  Blur overlay            ← covers everything below
 20  macOS Dock
  0  Normal app windows
```

---

## Roadmap

- [ ] Notarized DMG for seamless Gatekeeper bypass
- [ ] Timed auto-blur (set a duration)
- [ ] Per-app exclusions (keep specific windows above blur)
- [ ] Menu bar icon customisation
- [ ] Hotkey for cycling blur styles

---

## License

[MIT](../LICENSE) © [unsureifnerd](https://github.com/unsureifnerd)

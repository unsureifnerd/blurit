# BlurIt – Product Requirements Document&#x20;

## 1. Product Overview

BlurIt is a lightweight macOS menu bar application that allows users to manually apply a full-screen blur overlay across all active displays.

The blur intensity is adjustable, and users can optionally display customizable text over the blurred screen.

The application is designed to feel native to macOS, remain minimal, and prioritize performance and reliability.

Primary intent: Personal daily-use utility.
Secondary intent: Clean open-source macOS tool usable by others.

---

## 2. Target Platform

- Operating System: macOS&#x20;
- Language: Swift
- UI Framework: SwiftUI (preferred)
- Distribution: Open source (GitHub)
- App Type: Menu bar application (no Dock icon by default)

---

## 3. Core Capabilities

### 3.1 Manual Blur Toggle

- Blur can be toggled ON or OFF manually from the menu bar.
- Activation must be near-instant (<100ms perceived delay).
- Overlay must disappear instantly when disabled.

The app does not auto-detect recording or system activity.

---

### 3.2 Full-Screen Overlay

When enabled:

- A borderless overlay window is created per active display.
- Overlay covers all screens (multi-monitor support).
- Overlay stays always on top.
- Overlay blocks user interaction by default.
- Must function correctly across Spaces and full-screen apps.
- Must handle display sleep/wake events gracefully.

---

### 3.3 Blur Engine

- Use native macOS blur system (VisualEffectView / Material-based rendering).
- GPU-accelerated rendering required.
- Blur intensity adjustable via slider.

#### Blur Styles (Complete App Scope)

The app supports multiple selectable blur styles:

1. Standard Gaussian-style blur
2. Frosted glass (macOS-like material)
3. Soft light blur
4. Darkened blur (blur + dimming)
5. Minimal blur (subtle diffusion)

Users can switch styles from the menu.

---

### 3.4 Intensity Control

- Real-time adjustable blur intensity (0–100%).
- Smooth slider interaction.
- Changes must reflect immediately.
- Intensity setting persists between sessions.

---

### 3.5 Text Overlay System

Users may optionally display centered text over the blurred screen.

Text features:

- Editable text field
- Center alignment (default)
- Adjustable font size
- System font selection
- Text color picker
- Optional drop shadow
- Optional rounded background pill

Text should:

- Scale correctly across resolutions
- Remain crisp on high-DPI displays
- Hide automatically when text field is empty

---

### 3.6 Interaction Modes

Default Mode:

- Overlay blocks interaction beneath it.

Optional Mode:

- Click-through mode (overlay visible but allows interaction).
- Toggle available in settings.

---

### 3.7 Keyboard Shortcut Support

- Global hotkey to toggle blur on/off.
- Configurable shortcut in preferences.
- Must not conflict with system-reserved shortcuts.

---

### 3.8 Launch at Login

- Toggle available in menu or preferences.
- Uses macOS Login Items API.
- Persists across restarts.

---

## 4. Menu Structure

Menu Bar Dropdown Contains:

- Toggle: Blur On / Off
- Blur Style Selector
- Intensity Slider
- Text Input Field
- Font Size Slider
- Click-through Mode Toggle
- Keyboard Shortcut Configuration (opens small settings panel)
- Launch at Login Toggle
- Preferences (optional expandable panel)
- Quit

The UI must remain compact and minimal.

---

## 5. Preferences Panel (Expanded Configuration)

A small preferences window may include:

- Default blur style
- Default intensity
- Default text preset
- Click-through default state
- Keyboard shortcut configuration
- Launch at login
- Start with blur enabled (optional)

---

## 6. Performance Requirements

- Minimal CPU usage
- GPU-accelerated blur rendering
- No noticeable system slowdown
- Stable during long sessions (2+ hours)
- Memory footprint should remain lightweight

---

## 7. Stability Requirements

- Must support multi-monitor setups
- Must handle monitor unplug/replug
- Must handle sleep/wake cycles
- Must not flicker during toggle
- Must remain stable across Spaces and full-screen apps

---

## 8. UI & Design Guidelines

- Native macOS design language
- Rounded corners
- System materials
- Clean spacing
- No heavy custom theming
- Minimal visual clutter

The interface should feel like a built-in macOS utility.

---

## 9. Settings Persistence

Use UserDefaults to persist:

- Blur intensity
- Selected blur style
- Text content
- Font size
- Click-through state
- Keyboard shortcut
- Launch at login state

---

## 10. Architecture Overview

Core Components:

- App Entry
- MenuBarController
- OverlayManager
- BlurRenderer
- TextOverlayRenderer
- SettingsManager
- ShortcutManager
- LoginItemManager

OverlayManager must create and manage one overlay per active display.

---

## 11. Open Source Requirements

Repository must include:

- Clean project structure
- README with purpose and build instructions
- macOS version requirement clearly stated
- MIT License
- Contribution guidelines (optional)

No installer or auto-updater required.

---

## 12. Future Expansion Possibilities

- Scheduled auto-blur
- API or AppleScript integration
- Preset profiles
- Animation transitions
- Custom tint overlays
- Minimal overlay timer mode

These are optional and not required for core functionality.

---

## 13. Definition of Complete App

BlurIt is complete when:

- Blur works reliably across all displays
- Multiple blur styles function correctly
- Intensity adjusts smoothly
- Text overlay system is stable and customizable
- Click-through mode works correctly
- Keyboard shortcut toggles reliably
- Launch at login functions correctly
- No crashes during extended usage

---

End of PRD.


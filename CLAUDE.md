# BlurIt – Claude Code Instructions

## Project
macOS menu bar app in Swift/SwiftUI + AppKit hybrid.
Target: macOS 13+. No Dock icon. Menu bar only.

## Architecture
- Use AppKit for overlay windows (NSWindow, NSVisualEffectView)
- Use SwiftUI for menu and preferences UI
- Never use pure SwiftUI for window management — use AppKit
- One overlay NSWindow per NSScreen

## Code Rules
- Keep files small and focused (one class per file)
- Use UserDefaults with a wrapper class for all persistence
- Global shortcuts via CGEventTap or KeyboardShortcuts package
- Always handle multi-monitor: iterate NSScreen.screens

## Build Order
1. MenuBarController (NSStatusItem)
2. OverlayManager + OverlayWindow
3. BlurRenderer (NSVisualEffectView)
4. TextOverlayRenderer
5. ShortcutManager
6. SettingsManager + PreferencesView
7. LoginItemManager
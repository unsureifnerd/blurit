import AppKit
import Carbon

extension Notification.Name {
    static let shortcutPermissionGranted = Notification.Name("shortcutPermissionGranted")
}

/// Manages the global keyboard shortcut (CGEventTap) and double-ESC exit.
///
/// Key design: CGEventTap requires Accessibility permission.
/// If not granted at launch, a 1-second poll detects the moment the user
/// grants it and installs the tap automatically — no restart needed.
class ShortcutManager {
    static let shared = ShortcutManager()

    var onToggle: (() -> Void)?
    var isPermissionGranted: Bool { AXIsProcessTrusted() }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private let settings = SettingsManager.shared

    private var keyCode: UInt16 = 11                          // 'B'
    private var modifiers: NSEvent.ModifierFlags = [.command, .shift]

    // Double-ESC state
    private var lastEscTime: Date?
    private let escWindow: TimeInterval = 0.5                  // 500 ms between two ESCs

    private init() {}

    // MARK: - Public API

    func register() {
        keyCode  = settings.shortcutKeyCode != 0 ? settings.shortcutKeyCode : 11
        modifiers = settings.shortcutModifiers

        if AXIsProcessTrusted() {
            createEventTap()
        } else {
            // Ask once — macOS shows the "Trust this app?" system alert
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            // Poll every second; the moment permission is granted, install the tap
            startPolling()
        }
    }

    /// Call this from Preferences "Retry" button after user grants permission manually.
    /// Resets any stale TCC entry first (needed when Xcode rebuilds produce a new
    /// ad-hoc CDHash that no longer matches the previously-authorised binary).
    func retryRegistration() {
        resetTCCEntry()
        unregister()
        register()
    }

    /// Clears this app's Accessibility TCC entry so that the next
    /// AXIsProcessTrustedWithOptions(prompt:true) call produces a fresh prompt.
    private func resetTCCEntry() {
        let id = Bundle.main.bundleIdentifier ?? "com.blurit.app"
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments  = ["reset", "Accessibility", id]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }

    func unregister() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    func updateShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode   = keyCode
        self.modifiers = modifiers
        settings.shortcutKeyCode   = keyCode
        settings.shortcutModifiers = modifiers
        unregister()
        register()
    }

    // MARK: - Permission polling

    private func startPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.permissionTimer = nil
            self?.createEventTap()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .shortcutPermissionGranted, object: nil)
            }
        }
    }

    // MARK: - Event Tap

    private func createEventTap() {
        guard eventTap == nil else { return }   // already installed

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // NOTE: capture `eventType` (2nd arg) so we can detect tap-disable events.
        let callback: CGEventTapCallBack = { proxy, eventType, event, refcon in

            // ── Tap-disable recovery ─────────────────────────────────────────
            // macOS silences a slow tap. Re-enable immediately. Event is invalid here.
            if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
                if let refcon {
                    let mgr = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = mgr.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                }
                return nil
            }

            // From here: real keyDown event, event is guaranteed non-nil.
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()

            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

            // ── Double-ESC exit (keyCode 53) ────────────────────────────────
            if code == 53 {
                if OverlayManager.shared.isBlurActive {
                    let now = Date()
                    if let prev = mgr.lastEscTime, now.timeIntervalSince(prev) <= mgr.escWindow {
                        mgr.lastEscTime = nil
                        DispatchQueue.main.async { mgr.onToggle?() }
                    } else {
                        mgr.lastEscTime = now
                    }
                } else {
                    mgr.lastEscTime = nil
                }
                return Unmanaged.passUnretained(event)  // always pass ESC through
            }

            // ── Configured shortcut ──────────────────────────────────────────
            if mgr.matches(event: event) {
                DispatchQueue.main.async { mgr.onToggle?() }
                return nil  // consume the event
            }

            return Unmanaged.passUnretained(event)
        }

        let ptr = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: ptr
        )

        guard let tap = eventTap else {
            // tapCreate fails when the binary's code identity changed (new build).
            // Reset the TCC entry and re-prompt so the user can re-grant.
            print("[ShortcutManager] tapCreate failed — resetting TCC and re-prompting")
            if AXIsProcessTrusted() {
                // Old permission is stale (CDHash mismatch after rebuild).
                resetTCCEntry()
            }
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            startPolling()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[ShortcutManager] Event tap installed ✓  shortcut: \(shortcutDisplayString)")
    }

    // MARK: - Helpers

    private func matches(event: CGEvent) -> Bool {
        let code  = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return code == keyCode && flags.intersection(mask) == modifiers.intersection(mask)
    }

    var shortcutDisplayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append((keyCodeToString(keyCode) ?? "?").uppercased())
        return parts.joined()
    }

    private func keyCodeToString(_ code: UInt16) -> String? {
        let map: [UInt16: String] = [
            0:"a",1:"s",2:"d",3:"f",4:"h",5:"g",6:"z",7:"x",8:"c",9:"v",
            11:"b",12:"q",13:"w",14:"e",15:"r",16:"y",17:"t",31:"o",32:"u",
            34:"i",35:"p",37:"l",38:"j",40:"k",45:"n",46:"m",
        ]
        return map[code]
    }
}

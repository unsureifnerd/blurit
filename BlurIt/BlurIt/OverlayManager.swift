import AppKit

extension Notification.Name {
    static let blurStateDidChange = Notification.Name("blurStateDidChange")
}

/// Creates, shows, hides, and updates one OverlayWindow per connected screen.
class OverlayManager {
    static let shared = OverlayManager()

    private(set) var isBlurActive = false
    private var overlayWindows: [OverlayWindow] = []
    private var exitButtonWindows: [ExitButtonWindow] = []
    private let settings = SettingsManager.shared

    private init() {
        // Handle display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Handle sleep/wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func showOverlays() {
        removeAll()
        let duration = settings.animationDuration.seconds
        let position = settings.exitButtonPosition

        for screen in NSScreen.screens {
            let overlay = OverlayWindow(screen: screen)
            overlay.applySettings(settings)   // sets targetAlpha + alphaValue
            overlay.orderFrontRegardless()
            overlay.animateIn(duration: duration)  // fades 0 → targetAlpha (no-op if instant)
            overlayWindows.append(overlay)

            if position != .hidden {
                let exit = ExitButtonWindow(screen: screen, position: position) { [weak self] in
                    self?.hideOverlays()
                }
                exit.orderFrontRegardless()
                exitButtonWindows.append(exit)
            }
        }
        isBlurActive = true
        NotificationCenter.default.post(name: .blurStateDidChange, object: nil)
    }

    func hideOverlays() {
        let duration = settings.animationDuration.seconds
        let toRemove   = overlayWindows
        let exitRemove = exitButtonWindows
        overlayWindows      = []
        exitButtonWindows   = []

        // Exit buttons disappear immediately (no blur animation needed)
        exitRemove.forEach { $0.orderOut(nil) }

        isBlurActive = false
        NotificationCenter.default.post(name: .blurStateDidChange, object: nil)

        guard !toRemove.isEmpty else { return }

        if duration == 0 {
            toRemove.forEach { $0.orderOut(nil) }
        } else {
            for window in toRemove {
                window.animateOut(duration: duration) {
                    window.orderOut(nil)
                }
            }
        }
    }

    func updateAllOverlays() {
        guard isBlurActive else { return }
        for window in overlayWindows {
            window.applySettings(settings)
        }
    }

    private func removeAll() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        exitButtonWindows.forEach { $0.orderOut(nil) }
        exitButtonWindows.removeAll()
    }

    @objc private func screensChanged() {
        guard isBlurActive else { return }
        // Rebuild overlays to match new screen configuration
        showOverlays()
    }

    @objc private func systemDidWake() {
        guard isBlurActive else { return }
        // Small delay to let display settle after wake
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showOverlays()
        }
    }
}

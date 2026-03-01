import AppKit
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let settings = SettingsManager.shared
    private let overlayManager = OverlayManager.shared
    private let shortcutManager = ShortcutManager.shared

    override init() {
        super.init()
        setupStatusItem()
        setupShortcut()

        // Observe blur state from any source (exit button, ESC, shortcut)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(blurStateDidChange),
            name: .blurStateDidChange,
            object: nil
        )

        if settings.startWithBlur {
            overlayManager.showOverlays()
        }
        updateStatusIcon()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "BlurIt")
        button.image?.isTemplate = true
        buildMenu()
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Enable / Disable Blur
        let toggleTitle = overlayManager.isBlurActive ? "Disable Blur" : "Enable Blur"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleBlur), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // Blur Style submenu
        let styleMenu = NSMenu()
        for style in BlurStyle.allCases {
            let item = NSMenuItem(title: style.displayName,
                                  action: #selector(selectBlurStyle(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.tag   = style.rawValue
            item.state = (style == settings.blurStyle) ? .on : .off
            styleMenu.addItem(item)
        }
        let styleItem = NSMenuItem(title: "Blur Style", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit BlurIt",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc func toggleBlur() {
        if overlayManager.isBlurActive {
            overlayManager.hideOverlays()
        } else {
            overlayManager.showOverlays()
        }
        // blurStateDidChange notification handles menu/icon refresh
    }

    @objc private func selectBlurStyle(_ sender: NSMenuItem) {
        guard let style = BlurStyle(rawValue: sender.tag) else { return }
        settings.blurStyle = style
        overlayManager.updateAllOverlays()
        buildMenu()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    // MARK: - State sync (called whenever blur toggled from any source)

    @objc private func blurStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.buildMenu()
            self?.updateStatusIcon()
        }
    }

    // MARK: - Helpers

    private func setupShortcut() {
        shortcutManager.onToggle = { [weak self] in
            self?.toggleBlur()
        }
        shortcutManager.register()
    }

    private func updateStatusIcon() {
        // eye.slash.fill        = blur ON  (fully active)
        // eye.trianglebadge.exclamationmark.fill = preview mode ON
        // eye.fill              = blur OFF
        let name: String
        if overlayManager.isBlurActive && settings.previewMode {
            name = "eye.trianglebadge.exclamationmark.fill"
        } else if overlayManager.isBlurActive {
            name = "eye.slash.fill"
        } else {
            name = "eye.fill"
        }
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "BlurIt")
        statusItem.button?.image?.isTemplate = true
    }
}

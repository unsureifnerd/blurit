import AppKit
import SwiftUI

/// A borderless overlay window for one screen.
/// Level 100 sits above all normal app windows and the Dock (level 20),
/// but BELOW NSMenu dropdowns (level 101) — so the menu bar remains fully usable.
class OverlayWindow: NSWindow {

    let blurRenderer: BlurRenderer
    private let contentContainer = NSView()
    private var contentHosting: NSHostingView<ContentOverlayView>?

    /// The alpha the window should show at (set by applySettings; used by animateIn).
    private(set) var targetAlpha: CGFloat = 1.0

    init(screen: NSScreen) {
        blurRenderer = BlurRenderer(frame: .zero)

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        configure(for: screen)
        buildContentView()
    }

    private func configure(for screen: NSScreen) {
        // 100 = above Dock/apps, below NSMenu popups (101)
        level = NSWindow.Level(rawValue: 100)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        setFrame(screen.frame, display: false)
    }

    private func buildContentView() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        blurRenderer.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.addSubview(blurRenderer)

        let hosting = NSHostingView(rootView: ContentOverlayView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear
        contentContainer.addSubview(hosting)
        contentHosting = hosting

        contentView = contentContainer

        NSLayoutConstraint.activate([
            blurRenderer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            blurRenderer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            blurRenderer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            blurRenderer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            hosting.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    func applySettings(_ settings: SettingsManager) {
        blurRenderer.applyStyle(settings.blurStyle)
        blurRenderer.applyIntensity(settings.blurIntensity / 100.0)
        // Level 100: above Dock (20) and normal apps, below Preferences (102) and exit button (101).
        level = NSWindow.Level(rawValue: 100)
        targetAlpha = CGFloat(settings.blurIntensity / 100.0)
        // Preview mode forces click-through so the Preferences window (floating above at 102)
        // and exit button (101) receive all interaction while blur acts as a backdrop.
        ignoresMouseEvents = settings.previewMode || settings.clickThrough
        alphaValue = targetAlpha
    }

    // MARK: - Animation

    /// Fade from 0 → targetAlpha. Call after orderFrontRegardless().
    func animateIn(duration: Double) {
        guard duration > 0 else { return }
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = targetAlpha
        }
    }

    /// Fade from current alpha → 0, then call completion.
    func animateOut(duration: Double, completion: @escaping () -> Void) {
        guard duration > 0 else { completion(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: completion)
    }

    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }
}

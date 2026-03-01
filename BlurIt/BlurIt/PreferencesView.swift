import SwiftUI
import AppKit

// MARK: - Preferences Window Controller

class PreferencesWindowController: NSObject {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    private override init() {}

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PreferencesView()
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 460, height: 860)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 860),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "BlurIt"
        w.contentView = host
        w.center()
        w.isReleasedWhenClosed = false
        // 102 = above the blur overlay (100) and exit button (101),
        // so Preferences is always reachable even when blur is active.
        w.level = NSWindow.Level(rawValue: 102)

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Root: tabbed container

struct PreferencesView: View {
    var body: some View {
        TabView {
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle.fill") }
        }
        .frame(width: 460, height: 860)
    }
}

// MARK: - Settings Tab

private struct SettingsTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isRecordingShortcut = false
    @State private var localMonitor: Any?
    @State private var accessibilityGranted = AXIsProcessTrusted()

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            // ── Permissions ───────────────────────────────────────────────────
            Section("Permissions") {
                PermissionRow(
                    icon: "keyboard",
                    title: "Accessibility",
                    detail: "Required for global keyboard shortcut (\(ShortcutManager.shared.shortcutDisplayString)) and double-ESC. Tap \"Reset & Ask\" to re-trigger the system prompt.",
                    granted: accessibilityGranted,
                    onOpen: { openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") },
                    onRetry: { ShortcutManager.shared.retryRegistration() }
                )

                PermissionRow(
                    icon: "arrow.up.right.square",
                    title: "Login Items",
                    detail: "Required for Launch at Login.",
                    granted: LoginItemManager.shared.isEnabled || !settings.launchAtLogin,
                    onOpen: { openSystemSettings("x-apple.systempreferences:com.apple.LoginItems-Settings.extension") },
                    onRetry: nil
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .shortcutPermissionGranted)) { _ in
                withAnimation { accessibilityGranted = true }
            }

            // ── Blur ─────────────────────────────────────────────────────────
            Section("Blur") {
                Picker("Default Style", selection: $settings.blurStyle) {
                    ForEach(BlurStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .onChange(of: settings.blurStyle) { _ in OverlayManager.shared.updateAllOverlays() }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Intensity: \(Int(settings.blurIntensity))%").font(.callout)
                    Slider(value: $settings.blurIntensity, in: 10...100, step: 1)
                        .onChange(of: settings.blurIntensity) { _ in OverlayManager.shared.updateAllOverlays() }
                }

                Toggle("Start with blur enabled", isOn: $settings.startWithBlur)
            }

            // ── Clock ────────────────────────────────────────────────────────
            Section("Clock") {
                Toggle("Show Clock", isOn: $settings.showClock)

                Picker("Style", selection: $settings.clockStyle) {
                    ForEach(ClockStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .disabled(!settings.showClock)

                Toggle("24-hour format", isOn: $settings.clockIs24Hour)
                    .disabled(!settings.showClock
                              || settings.clockStyle == .analog
                              || settings.clockStyle == .analogMinimal
                              || settings.clockStyle == .analogArc
                              || settings.clockStyle == .fuzzy)
            }

            // ── Text Overlay ─────────────────────────────────────────────────
            Section("Text Overlay") {
                Picker("Style", selection: $settings.textStyle) {
                    ForEach(TextStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .onChange(of: settings.textStyle) { _ in OverlayManager.shared.updateAllOverlays() }

                TextField("Overlay text", text: $settings.overlayText)
                    .onChange(of: settings.overlayText) { _ in OverlayManager.shared.updateAllOverlays() }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Font Size: \(Int(settings.fontSize))pt").font(.callout)
                    Slider(value: $settings.fontSize, in: 12...96, step: 2)
                        .onChange(of: settings.fontSize) { _ in OverlayManager.shared.updateAllOverlays() }
                }

                ColorPickerRow(settings: settings)

                Toggle("Drop shadow", isOn: $settings.showTextShadow)
                    .onChange(of: settings.showTextShadow) { _ in OverlayManager.shared.updateAllOverlays() }

                Toggle("Background pill", isOn: $settings.showTextBackground)
                    .onChange(of: settings.showTextBackground) { _ in OverlayManager.shared.updateAllOverlays() }
            }

            // ── Exit Door ────────────────────────────────────────────────────
            Section("Exit Door") {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Press **ESC** twice (within 0.5 s) to exit blur at any time. Requires Accessibility permission above.")
                    } icon: {
                        Image(systemName: "escape")
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)

                    Divider()

                    Text("Exit button position").font(.callout)
                    ExitButtonPositionPicker(position: $settings.exitButtonPosition)
                        .onChange(of: settings.exitButtonPosition) { _ in
                            if OverlayManager.shared.isBlurActive {
                                OverlayManager.shared.hideOverlays()
                                OverlayManager.shared.showOverlays()
                            }
                        }
                    Text("Floats above the blur on every screen. \"Hidden\" disables it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // ── Behavior ─────────────────────────────────────────────────────
            Section("Behavior") {
                Toggle("Click-through mode", isOn: $settings.clickThrough)
                    .onChange(of: settings.clickThrough) { _ in OverlayManager.shared.updateAllOverlays() }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Preview Mode", isOn: $settings.previewMode)
                        .onChange(of: settings.previewMode) { newValue in
                            if newValue {
                                // ON → auto-start blur; Preferences floats above it at level 102
                                if !OverlayManager.shared.isBlurActive {
                                    OverlayManager.shared.showOverlays()
                                } else {
                                    OverlayManager.shared.updateAllOverlays()
                                }
                            } else {
                                // OFF → hide blur
                                OverlayManager.shared.hideOverlays()
                            }
                        }
                    Text("Preview auto-starts blur. This window sits above the blur (level 102) so you can tune settings live. Turning preview off hides the blur.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Picker("Blur animation", selection: $settings.animationDuration) {
                    ForEach(AnimationDuration.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            // ── Keyboard Shortcut ─────────────────────────────────────────────
            Section("Keyboard Shortcut") {
                HStack {
                    Text("Toggle shortcut:")
                    Spacer()
                    Button(isRecordingShortcut
                           ? "Press keys…"
                           : ShortcutManager.shared.shortcutDisplayString) {
                        startRecording()
                    }
                    .buttonStyle(.bordered)
                }
                if !accessibilityGranted {
                    Text("Grant Accessibility permission above for the shortcut to work.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .onAppear { accessibilityGranted = AXIsProcessTrusted() }
        .onReceive(permissionTimer) { _ in
            let current = AXIsProcessTrusted()
            if current != accessibilityGranted {
                withAnimation { accessibilityGranted = current }
                if current { ShortcutManager.shared.retryRegistration() }
            }
        }
    }

    private func startRecording() {
        isRecordingShortcut = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }
            ShortcutManager.shared.updateShortcut(keyCode: event.keyCode, modifiers: mods)
            self.isRecordingShortcut = false
            if let m = self.localMonitor { NSEvent.removeMonitor(m); self.localMonitor = nil }
            return nil
        }
    }

    private func openSystemSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            if let img = NSImage(named: "AppIcon") {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
            }

            Spacer().frame(height: 20)

            // Name + version
            Text("BlurIt")
                .font(.system(size: 30, weight: .semibold, design: .rounded))

            Text("Version \(version) (\(build))")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Spacer().frame(height: 24)

            // Description
            Text("A lightweight macOS menu bar app that blankets your screen in beautiful blur effects — ideal for presentations, focus sessions, and quick privacy.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 52)

            Spacer().frame(height: 32)

            Divider().padding(.horizontal, 60)

            Spacer().frame(height: 28)

            // Developer card
            VStack(spacing: 16) {
                Text("Developer")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/unsureifnerd")!)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 14, weight: .medium))
                        Text("github.com/unsureifnerd")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    NSCursor.pointingHand.set()
                    if !hovering { NSCursor.arrow.set() }
                }
            }

            Spacer().frame(height: 28)

            Divider().padding(.horizontal, 60)

            Spacer().frame(height: 20)

            // Footer
            Text("Made with ♥ on macOS")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let onOpen: () -> Void
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(granted ? .green : .red)
                    .imageScale(.medium)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title).fontWeight(.medium)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !granted {
                    if let retry = onRetry {
                        Button("Reset & Ask") { retry() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Button("Open Settings") { onOpen() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else {
                    Text("Granted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Color Picker Row (bridges NSColorPanel → SwiftUI)

struct ColorPickerRow: NSViewRepresentable {
    @ObservedObject var settings: SettingsManager

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.color = settings.textColor
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        well.controlSize = .small
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        nsView.color = settings.textColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(settings: settings) }

    class Coordinator: NSObject {
        let settings: SettingsManager
        init(settings: SettingsManager) { self.settings = settings }

        @objc func colorChanged(_ sender: NSColorWell) {
            settings.textColor = sender.color
            OverlayManager.shared.updateAllOverlays()
        }
    }
}

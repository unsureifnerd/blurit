import AppKit
import SwiftUI

// MARK: - Exit Button Position

enum ExitButtonPosition: Int, CaseIterable, Identifiable, Hashable {
    case topLeft = 0, topCenter = 1, topRight = 2
    case middleLeft = 3, center = 4, middleRight = 5
    case bottomLeft = 6, bottomCenter = 7, bottomRight = 8
    case hidden = 9

    var id: Int { rawValue }
}

// MARK: - Exit Button Window

/// A small always-interactive window that floats above the blur overlay.
/// Always ignoresMouseEvents = false, regardless of click-through setting.
class ExitButtonWindow: NSWindow {

    // Visible button area; window is slightly larger to allow shadow rendering
    static let buttonSize  = CGSize(width: 130, height: 38)
    static let padding: CGFloat = 14
    static var windowSize: CGSize {
        CGSize(width: buttonSize.width + padding * 2,
               height: buttonSize.height + padding * 2)
    }

    init(screen: NSScreen, position: ExitButtonPosition, onExit: @escaping () -> Void) {
        let frame = ExitButtonWindow.windowFrame(for: position, on: screen)

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // 101 = one above our overlay (100), same as NSMenu — but always interactive
        level = NSWindow.Level(rawValue: 101)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let view = ExitButtonView(onExit: onExit)
            .padding(ExitButtonWindow.padding)     // lets shadow breathe
            .frame(width: ExitButtonWindow.windowSize.width,
                   height: ExitButtonWindow.windowSize.height)

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: ExitButtonWindow.windowSize)
        contentView = hosting
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = CGColor.clear
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Position calculation

    static func windowFrame(for position: ExitButtonPosition, on screen: NSScreen) -> NSRect {
        guard position != .hidden else { return .zero }
        let sf = screen.frame
        let sz = windowSize
        let m: CGFloat = 20   // margin from screen edge (visual, excludes padding)

        var x: CGFloat
        var y: CGFloat

        switch position {
        case .topLeft:
            x = sf.minX + m - padding;         y = sf.maxY - buttonSize.height - m - padding
        case .topCenter:
            x = sf.midX - sz.width / 2;        y = sf.maxY - buttonSize.height - m - padding
        case .topRight:
            x = sf.maxX - buttonSize.width - m - padding; y = sf.maxY - buttonSize.height - m - padding
        case .middleLeft:
            x = sf.minX + m - padding;         y = sf.midY - sz.height / 2
        case .center:
            x = sf.midX - sz.width / 2;        y = sf.midY - sz.height / 2
        case .middleRight:
            x = sf.maxX - buttonSize.width - m - padding; y = sf.midY - sz.height / 2
        case .bottomLeft:
            x = sf.minX + m - padding;         y = sf.minY + m - padding
        case .bottomCenter:
            x = sf.midX - sz.width / 2;        y = sf.minY + m - padding
        case .bottomRight:
            x = sf.maxX - buttonSize.width - m - padding; y = sf.minY + m - padding
        case .hidden:
            return .zero
        }

        return NSRect(x: x, y: y, width: sz.width, height: sz.height)
    }
}

// MARK: - Exit Button View

struct ExitButtonView: View {
    let onExit: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onExit) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.medium)
                Text("Exit Blur")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isHovering ? Color.red.opacity(0.9) : Color.black.opacity(0.65))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Position Picker (used in PreferencesView)

struct ExitButtonPositionPicker: View {
    @Binding var position: ExitButtonPosition

    private let grid: [[ExitButtonPosition]] = [
        [.topLeft,    .topCenter,    .topRight],
        [.middleLeft, .center,       .middleRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 3×3 grid
            VStack(spacing: 3) {
                ForEach(grid, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(row) { pos in
                            gridCell(for: pos)
                        }
                    }
                }
            }

            Divider().frame(height: 90)

            // Hidden option
            VStack(spacing: 4) {
                gridCell(for: .hidden, icon: "eye.slash.fill")
                Text("Hidden")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func gridCell(for pos: ExitButtonPosition, icon: String? = nil) -> some View {
        let selected = position == pos
        Button { position = pos } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(selected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6))
                .frame(width: 30, height: 30)
                .overlay {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 10))
                            .foregroundColor(selected ? .white : .secondary)
                    } else {
                        Circle()
                            .fill(selected ? .white : Color.secondary.opacity(0.6))
                            .frame(width: 7, height: 7)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

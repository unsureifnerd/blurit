import AppKit

// MARK: - BlurRenderer

/// Renders the blur effect for a single overlay window.
/// Wraps a primary NSVisualEffectView and — for pattern styles — installs a
/// lightweight NSView overlay that composites the pattern on top of the blur.
///
/// currentStyle tracking: applyStyle() is a no-op when the style hasn't changed,
/// so intensity-slider ticks (which call applySettings on every move) never tear
/// down and recreate the view hierarchy unnecessarily.
class BlurRenderer: NSView {

    private let primaryEffect = NSVisualEffectView()
    private let dimLayer      = CALayer()

    private var currentStyle: BlurStyle?
    private weak var patternView: NSView?   // owned by the view hierarchy, not this property

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        primaryEffect.translatesAutoresizingMaskIntoConstraints = false
        primaryEffect.blendingMode = .behindWindow
        primaryEffect.state        = .active
        addSubview(primaryEffect)

        NSLayoutConstraint.activate([
            primaryEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            primaryEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            primaryEffect.topAnchor.constraint(equalTo: topAnchor),
            primaryEffect.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0).cgColor
        layer?.addSublayer(dimLayer)
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        dimLayer.frame = bounds
        patternView?.frame = bounds
    }

    // MARK: - Public API

    func applyStyle(_ style: BlurStyle) {
        guard style != currentStyle else { return }
        currentStyle = style

        // Update the primary NSVisualEffectView
        primaryEffect.material   = style.material
        primaryEffect.appearance = style.appearanceOverride

        // Tear down whatever pattern view existed before
        teardownPatternView()

        // Install the new one if this style needs it
        if style.requiresPatternView {
            setupPatternView(for: style)
        }
    }

    /// Intensity (0–1) is also applied as the window's alphaValue by OverlayWindow.
    func applyIntensity(_ intensity: Double) {
        let clamped  = max(0, min(1, intensity))
        let dimAlpha = (1.0 - clamped) * 0.0   // reserved for per-style dim
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(dimAlpha).cgColor
        CATransaction.commit()
    }

    // MARK: - Pattern view lifecycle

    private func teardownPatternView() {
        patternView?.removeFromSuperview()
        patternView = nil
    }

    private func setupPatternView(for style: BlurStyle) {
        let view: NSView
        switch style {
        case .mosaic:      view = MosaicPatternView(frame: bounds)
        case .chessboard:  view = ChessboardPatternView(frame: bounds)
        case .dotMatrix:   view = DotMatrixPatternView(frame: bounds)
        case .stripes:     view = StripesPatternView(frame: bounds)
        default:           return
        }

        // autoresizingMask keeps the pattern flush when bounds change;
        // dimLayer (a CALayer, not a subview) naturally sits on top.
        view.autoresizingMask = [.width, .height]
        addSubview(view, positioned: .above, relativeTo: primaryEffect)
        patternView = view
    }
}

// MARK: - Mosaic Pattern

/// Tiled glass rectangles with 2 pt grout lines.
/// Alternating tiles carry a slight white/dark tint to simulate depth.
private final class MosaicPatternView: NSView {

    private let tileSize:  CGFloat = 58.0
    private let groutSize: CGFloat = 2.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque        = false
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let stride = tileSize + groutSize
        let cols   = Int(ceil(bounds.width  / stride)) + 1
        let rows   = Int(ceil(bounds.height / stride)) + 1

        // Step 1: draw semi-opaque grout over the whole area
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
        ctx.fill(bounds)

        // Step 2: for each tile, punch a transparent hole then add a tint
        for row in 0..<rows {
            for col in 0..<cols {
                let x    = CGFloat(col) * stride
                let y    = CGFloat(row) * stride
                let tile = CGRect(x: x + groutSize, y: y + groutSize,
                                  width: tileSize - groutSize,
                                  height: tileSize - groutSize)

                // Erase to alpha = 0 (shows the NSVisualEffectView beneath)
                ctx.setBlendMode(.clear)
                ctx.fill(tile)
                ctx.setBlendMode(.normal)

                // Deterministic tint: alternates light / dark based on position
                let seed  = (row * 7 + col * 13) % 16
                let delta = CGFloat(seed) / 16.0        // 0.0 … ~0.94

                if delta > 0.5 {
                    let a = (delta - 0.5) * 0.28
                    ctx.setFillColor(NSColor.white.withAlphaComponent(a).cgColor)
                } else {
                    let a = (0.5 - delta) * 0.22
                    ctx.setFillColor(NSColor.black.withAlphaComponent(a).cgColor)
                }
                ctx.fill(tile)

                // 1 pt top-edge highlight → frosted glass bevel feel
                let bevel = CGRect(x: tile.minX, y: tile.maxY - 1,
                                   width: tile.width, height: 1)
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
                ctx.fill(bevel)
            }
        }

        ctx.setBlendMode(.normal)   // defensive reset
    }
}

// MARK: - Chessboard Pattern

/// Two stacked NSVisualEffectViews — frost (sidebar/aqua) and dark
/// (underPageBackground/darkAqua) — where the dark layer is masked to the
/// "black" squares of an 80 pt chess grid via a CAShapeLayer on its container.
private final class ChessboardPatternView: NSView {

    private let squareSize: CGFloat = 80.0

    private let lightVEV      = NSVisualEffectView()
    private let darkContainer = NSView()
    private let darkVEV       = NSVisualEffectView()
    private let maskLayer     = CAShapeLayer()

    private var lastMaskedBounds = CGRect.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque        = false
        layer?.backgroundColor = .clear
        buildSubviews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildSubviews() {
        // Light VEV — full area, aqua frosted glass
        lightVEV.material      = .sidebar
        lightVEV.appearance    = NSAppearance(named: .aqua)
        lightVEV.blendingMode  = .behindWindow
        lightVEV.state         = .active
        lightVEV.autoresizingMask = [.width, .height]
        addSubview(lightVEV)

        // Dark VEV — inside a masked container
        darkVEV.material       = .underPageBackground
        darkVEV.appearance     = NSAppearance(named: .darkAqua)
        darkVEV.blendingMode   = .behindWindow
        darkVEV.state          = .active
        darkVEV.autoresizingMask = [.width, .height]
        darkContainer.addSubview(darkVEV)

        darkContainer.wantsLayer             = true
        darkContainer.layer?.isOpaque        = false
        darkContainer.layer?.mask            = maskLayer
        darkContainer.autoresizingMask       = [.width, .height]
        addSubview(darkContainer)
    }

    override func layout() {
        super.layout()
        lightVEV.frame      = bounds
        darkContainer.frame = bounds
        darkVEV.frame       = darkContainer.bounds

        guard bounds != lastMaskedBounds else { return }
        lastMaskedBounds = bounds
        rebuildMask()
    }

    private func rebuildMask() {
        let path = CGMutablePath()
        let cols = Int(ceil(bounds.width  / squareSize)) + 1
        let rows = Int(ceil(bounds.height / squareSize)) + 1

        for row in 0..<rows {
            for col in 0..<cols {
                guard (col + row) % 2 == 1 else { continue }   // "dark" squares
                path.addRect(CGRect(
                    x: CGFloat(col) * squareSize,
                    y: CGFloat(row) * squareSize,
                    width:  squareSize,
                    height: squareSize
                ))
            }
        }

        maskLayer.path      = path
        maskLayer.fillColor = NSColor.white.cgColor   // white = visible in mask
        maskLayer.frame     = darkContainer.bounds
    }
}

// MARK: - Dot Matrix Pattern

/// Semi-opaque overlay with circular apertures punched in a honeycomb grid.
/// CGBlendMode.clear erases the circle pixels back to alpha = 0, letting
/// the NSVisualEffectView beneath show through each dot cleanly.
private final class DotMatrixPatternView: NSView {

    private let dotRadius:   CGFloat = 17.0
    private let spacingX:    CGFloat = 44.0
    private let spacingY:    CGFloat = 38.0   // tighter rows → honeycomb
    private let overlayAlpha: CGFloat = 0.50

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque        = false
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1. Flood-fill with semi-opaque overlay (the "matrix" between dots)
        ctx.setFillColor(NSColor.black.withAlphaComponent(overlayAlpha).cgColor)
        ctx.fill(bounds)

        // 2. Punch circular holes — honeycomb offset on every other row
        ctx.setBlendMode(.clear)

        let cols = Int(ceil(bounds.width  / spacingX)) + 2
        let rows = Int(ceil(bounds.height / spacingY)) + 2

        for row in 0...rows {
            let yCenter = CGFloat(row) * spacingY
            let xOff    = (row % 2 == 0) ? 0.0 : spacingX / 2.0

            for col in 0...cols {
                let xCenter = CGFloat(col) * spacingX + xOff
                ctx.fillEllipse(in: CGRect(
                    x: xCenter - dotRadius,
                    y: yCenter - dotRadius,
                    width:  dotRadius * 2,
                    height: dotRadius * 2
                ))
            }
        }

        ctx.setBlendMode(.normal)   // defensive reset
    }
}

// MARK: - Stripes Pattern

/// 45° diagonal stripe bands: alternating semi-opaque and transparent.
/// Uses NSColor(patternImage:) so the tile is rasterised once and then
/// tiled at no extra per-draw cost over the full screen.
private final class StripesPatternView: NSView {

    private let stripeWidth:  CGFloat = 24.0
    private let stripeAlpha:  CGFloat = 0.42
    private var patternColor: NSColor?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque        = false
        layer?.backgroundColor = .clear
        buildPatternColor()
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isOpaque: Bool { false }

    private func buildPatternColor() {
        // Period = stripe + gap (equal widths).
        // For seamless 45° tiling, tile must be square with side = period * √2.
        let period:   CGFloat = stripeWidth * 2
        let tileSize: CGFloat = ceil(period * 1.4143)   // ≈ period × √2, integer pt

        let image = NSImage(size: NSSize(width: tileSize, height: tileSize),
                            flipped: false) { [self] rect in
            // Transparent background (the "gap" bands)
            NSColor.clear.setFill()
            rect.fill()

            // Draw the opaque stripe bands as parallelograms at 45°
            let path  = NSBezierPath()
            let diag  = tileSize + period    // enough overshoot past any edge

            var offset: CGFloat = -period
            while offset < diag {
                path.move(to:  NSPoint(x: offset,               y: 0))
                path.line(to:  NSPoint(x: offset + stripeWidth,  y: 0))
                path.line(to:  NSPoint(x: offset + stripeWidth + tileSize, y: tileSize))
                path.line(to:  NSPoint(x: offset + tileSize,    y: tileSize))
                path.close()
                offset += period
            }

            NSColor.white.withAlphaComponent(self.stripeAlpha).setFill()
            path.fill()
            return true
        }

        patternColor = NSColor(patternImage: image)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let color = patternColor else { return }

        // Anchor pattern phase to view origin so stripes don't shift across screens
        ctx.setPatternPhase(CGSize(width: bounds.minX, height: bounds.minY))
        ctx.setFillColor(color.cgColor)
        ctx.fill(bounds)
    }
}

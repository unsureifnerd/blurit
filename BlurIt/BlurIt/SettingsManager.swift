import Foundation
import AppKit

// MARK: - Blur Style

enum BlurStyle: Int, CaseIterable, Identifiable {
    // ── Original styles ───────────────────────────────────────────
    case standardGaussian = 0
    case frostedGlass     = 1
    case softLight        = 2
    case darkened         = 3
    case minimal          = 4
    // ── Pattern styles ────────────────────────────────────────────
    case mosaic           = 5   // tiled glass squares with grout lines
    case chessboard       = 6   // alternating frost / dark squares
    case dotMatrix        = 7   // honeycomb dot apertures
    case stripes          = 8   // 45° diagonal stripe bands

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .standardGaussian: return "Standard"
        case .frostedGlass:     return "Frosted Glass"
        case .softLight:        return "Soft Light"
        case .darkened:         return "Darkened"
        case .minimal:          return "Minimal"
        case .mosaic:           return "Mosaic"
        case .chessboard:       return "Chessboard"
        case .dotMatrix:        return "Dot Matrix"
        case .stripes:          return "Stripes"
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .standardGaussian: return .hudWindow
        case .frostedGlass:     return .sheet
        case .softLight:        return .sidebar
        case .darkened:         return .underPageBackground
        case .minimal:          return .contentBackground
        case .mosaic:           return .hudWindow
        case .chessboard:       return .sidebar   // primary = frost; secondary handled in BlurRenderer
        case .dotMatrix:        return .hudWindow
        case .stripes:          return .hudWindow
        }
    }

    var appearanceOverride: NSAppearance? {
        switch self {
        case .softLight:        return NSAppearance(named: .aqua)
        case .darkened:         return NSAppearance(named: .darkAqua)
        default:                return nil
        }
    }

    /// True when BlurRenderer needs to install a pattern overlay NSView.
    var requiresPatternView: Bool {
        switch self {
        case .mosaic, .chessboard, .dotMatrix, .stripes: return true
        default: return false
        }
    }
}

// MARK: - Clock Style

enum ClockStyle: Int, CaseIterable, Identifiable {
    case digitalModern  = 0
    case digitalRetro   = 1
    case analog         = 2
    case analogMinimal  = 3
    case digitalBold    = 4   // large black digits + date line
    case neon           = 5   // cyan/magenta neon glow
    case fuzzy          = 6   // "quarter past three"
    case analogArc      = 7   // arc-sector hands instead of lines

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .digitalModern:  return "Digital – Modern"
        case .digitalRetro:   return "Digital – Retro"
        case .analog:         return "Analog"
        case .analogMinimal:  return "Analog – Minimal"
        case .digitalBold:    return "Digital – Bold"
        case .neon:           return "Neon"
        case .fuzzy:          return "Fuzzy"
        case .analogArc:      return "Analog – Arc"
        }
    }
}

// MARK: - Animation Duration

enum AnimationDuration: Int, CaseIterable, Identifiable {
    case instant = 0
    case fast    = 1   // 0.2 s
    case medium  = 2   // 0.45 s
    case slow    = 3   // 0.85 s

    var id: Int { rawValue }

    var seconds: Double {
        switch self {
        case .instant: return 0.0
        case .fast:    return 0.20
        case .medium:  return 0.45
        case .slow:    return 0.85
        }
    }

    var displayName: String {
        switch self {
        case .instant: return "Instant"
        case .fast:    return "Fast (0.2 s)"
        case .medium:  return "Medium (0.45 s)"
        case .slow:    return "Slow (0.85 s)"
        }
    }
}

// MARK: - Text Style

enum TextStyle: Int, CaseIterable, Identifiable {
    case plain    = 0   // clean text, honours shadow/background toggles
    case neon     = 1   // multi-layer glow using the chosen text colour
    case retro    = 2   // green phosphor monospace on a dark terminal panel
    case glass    = 3   // text on an ultra-thin material (frosted) pill
    case outlined = 4   // hollow stroke outline

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .plain:    return "Plain"
        case .neon:     return "Neon Glow"
        case .retro:    return "Retro Terminal"
        case .glass:    return "Frosted Glass"
        case .outlined: return "Outlined"
        }
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let blurIntensity      = "blurIntensity"
        static let blurStyle          = "blurStyle"
        static let overlayText        = "overlayText"
        static let fontSize           = "fontSize"
        static let clickThrough       = "clickThrough"
        static let launchAtLogin      = "launchAtLogin"
        static let textColor          = "textColor"
        static let showTextShadow     = "showTextShadow"
        static let showTextBackground = "showTextBackground"
        static let startWithBlur      = "startWithBlur"
        static let shortcutKeyCode    = "shortcutKeyCode"
        static let shortcutModifiers  = "shortcutModifiers"
        static let exitButtonPosition = "exitButtonPosition"
        static let showClock          = "showClock"
        static let clockStyle         = "clockStyle"
        static let clockIs24Hour      = "clockIs24Hour"
        static let previewMode        = "previewMode"
        static let animationDuration  = "animationDuration"
        static let textStyle          = "textStyle"
    }

    @Published var blurIntensity: Double {
        didSet { defaults.set(blurIntensity, forKey: Keys.blurIntensity) }
    }

    @Published var blurStyle: BlurStyle {
        didSet { defaults.set(blurStyle.rawValue, forKey: Keys.blurStyle) }
    }

    @Published var overlayText: String {
        didSet { defaults.set(overlayText, forKey: Keys.overlayText) }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var clickThrough: Bool {
        didSet { defaults.set(clickThrough, forKey: Keys.clickThrough) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LoginItemManager.shared.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    @Published var textColorData: Data {
        didSet { defaults.set(textColorData, forKey: Keys.textColor) }
    }

    @Published var showTextShadow: Bool {
        didSet { defaults.set(showTextShadow, forKey: Keys.showTextShadow) }
    }

    @Published var showTextBackground: Bool {
        didSet { defaults.set(showTextBackground, forKey: Keys.showTextBackground) }
    }

    @Published var startWithBlur: Bool {
        didSet { defaults.set(startWithBlur, forKey: Keys.startWithBlur) }
    }

    @Published var exitButtonPosition: ExitButtonPosition {
        didSet { defaults.set(exitButtonPosition.rawValue, forKey: Keys.exitButtonPosition) }
    }

    @Published var showClock: Bool {
        didSet { defaults.set(showClock, forKey: Keys.showClock) }
    }

    @Published var clockStyle: ClockStyle {
        didSet { defaults.set(clockStyle.rawValue, forKey: Keys.clockStyle) }
    }

    @Published var clockIs24Hour: Bool {
        didSet { defaults.set(clockIs24Hour, forKey: Keys.clockIs24Hour) }
    }

    @Published var previewMode: Bool {
        didSet { defaults.set(previewMode, forKey: Keys.previewMode) }
    }

    @Published var animationDuration: AnimationDuration {
        didSet { defaults.set(animationDuration.rawValue, forKey: Keys.animationDuration) }
    }

    @Published var textStyle: TextStyle {
        didSet { defaults.set(textStyle.rawValue, forKey: Keys.textStyle) }
    }

    var shortcutKeyCode: UInt16 {
        get { UInt16(defaults.integer(forKey: Keys.shortcutKeyCode)) }
        set { defaults.set(Int(newValue), forKey: Keys.shortcutKeyCode) }
    }

    var shortcutModifiers: NSEvent.ModifierFlags {
        get {
            let raw = defaults.integer(forKey: Keys.shortcutModifiers)
            return raw != 0
                ? NSEvent.ModifierFlags(rawValue: UInt(raw))
                : [.command, .shift]
        }
        set { defaults.set(Int(newValue.rawValue), forKey: Keys.shortcutModifiers) }
    }

    var textColor: NSColor {
        get {
            guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: textColorData) else {
                return .white
            }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                textColorData = data
            }
        }
    }

    private init() {
        blurIntensity      = defaults.object(forKey: Keys.blurIntensity) as? Double ?? 80.0
        blurStyle          = BlurStyle(rawValue: defaults.integer(forKey: Keys.blurStyle)) ?? .frostedGlass
        overlayText        = defaults.string(forKey: Keys.overlayText) ?? ""
        fontSize           = defaults.object(forKey: Keys.fontSize) as? Double ?? 32.0
        clickThrough       = defaults.bool(forKey: Keys.clickThrough)
        launchAtLogin      = defaults.bool(forKey: Keys.launchAtLogin)
        showTextShadow     = defaults.object(forKey: Keys.showTextShadow) as? Bool ?? true
        showTextBackground = defaults.object(forKey: Keys.showTextBackground) as? Bool ?? false
        startWithBlur      = defaults.bool(forKey: Keys.startWithBlur)
        exitButtonPosition = ExitButtonPosition(rawValue: defaults.integer(forKey: Keys.exitButtonPosition)) ?? .bottomRight
        showClock          = defaults.bool(forKey: Keys.showClock)
        clockStyle         = ClockStyle(rawValue: defaults.integer(forKey: Keys.clockStyle)) ?? .digitalModern
        clockIs24Hour      = defaults.object(forKey: Keys.clockIs24Hour) as? Bool ?? true
        previewMode        = defaults.bool(forKey: Keys.previewMode)
        animationDuration  = AnimationDuration(rawValue: defaults.integer(forKey: Keys.animationDuration)) ?? .fast
        textStyle          = TextStyle(rawValue: defaults.integer(forKey: Keys.textStyle)) ?? .plain
        textColorData      = defaults.data(forKey: Keys.textColor)
            ?? (try? NSKeyedArchiver.archivedData(withRootObject: NSColor.white, requiringSecureCoding: false))
            ?? Data()
    }
}

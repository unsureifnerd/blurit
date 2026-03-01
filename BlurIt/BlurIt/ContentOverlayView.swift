import SwiftUI

// MARK: - Unified content view (text + clock, stacked)

struct ContentOverlayView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        let hasText  = !settings.overlayText.isEmpty
        let hasClock = settings.showClock

        ZStack {
            if hasText || hasClock {
                VStack(spacing: 28) {
                    if hasText  { TextContent(settings: settings) }
                    if hasClock {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            ClockContent(date: ctx.date, settings: settings)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Text router

struct TextContent: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        switch settings.textStyle {
        case .plain:    PlainTextView(settings: settings)
        case .neon:     NeonTextView(settings: settings)
        case .retro:    RetroTextView(settings: settings)
        case .glass:    GlassTextView(settings: settings)
        case .outlined: OutlinedTextView(settings: settings)
        }
    }
}

// MARK: - Plain (current behaviour, respects shadow + background toggles)

private struct PlainTextView: View {
    @ObservedObject var settings: SettingsManager
    var body: some View {
        Text(settings.overlayText)
            .font(.system(size: settings.fontSize, weight: .semibold))
            .foregroundColor(Color(settings.textColor))
            .multilineTextAlignment(.center)
            .shadow(color: settings.showTextShadow ? .black.opacity(0.6) : .clear,
                    radius: 8, x: 0, y: -2)
            .padding(.horizontal, 20)
            .padding(.vertical, settings.showTextBackground ? 12 : 0)
            .background {
                if settings.showTextBackground { Capsule().fill(Color.black.opacity(0.35)) }
            }
    }
}

// MARK: - Neon (multi-layer colour glow)

private struct NeonTextView: View {
    @ObservedObject var settings: SettingsManager
    var body: some View {
        let c = Color(settings.textColor)
        Text(settings.overlayText)
            .font(.system(size: settings.fontSize, weight: .medium))
            .foregroundColor(c)
            .multilineTextAlignment(.center)
            .shadow(color: c.opacity(0.9), radius: 14)
            .shadow(color: c.opacity(0.5), radius: 28)
            .shadow(color: c.opacity(0.25), radius: 48)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(c.opacity(0.2), lineWidth: 1))
            }
    }
}

// MARK: - Retro Terminal (green phosphor monospace)

private struct RetroTextView: View {
    @ObservedObject var settings: SettingsManager
    private let phosphor = Color(red: 0.15, green: 1.0, blue: 0.35)
    var body: some View {
        Text(settings.overlayText)
            .font(.system(size: settings.fontSize, weight: .regular, design: .monospaced))
            .foregroundColor(phosphor)
            .multilineTextAlignment(.center)
            .shadow(color: phosphor.opacity(0.8), radius: 10)
            .shadow(color: phosphor.opacity(0.4), radius: 22)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.65))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(phosphor.opacity(0.2), lineWidth: 1))
            }
    }
}

// MARK: - Frosted Glass (ultra-thin material pill)

private struct GlassTextView: View {
    @ObservedObject var settings: SettingsManager
    var body: some View {
        Text(settings.overlayText)
            .font(.system(size: settings.fontSize, weight: .semibold))
            .foregroundColor(Color(settings.textColor))
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Outlined (stroke silhouette, no fill)

private struct OutlinedTextView: View {
    @ObservedObject var settings: SettingsManager
    var body: some View {
        let c = Color(settings.textColor)
        let text = settings.overlayText
        let font = Font.system(size: settings.fontSize, weight: .bold)
        ZStack {
            // Eight-direction stroke using offsets
            ForEach([-1, 0, 1], id: \.self) { dx in
                ForEach([-1, 0, 1], id: \.self) { dy in
                    if dx != 0 || dy != 0 {
                        Text(text)
                            .font(font)
                            .foregroundColor(.black.opacity(0.85))
                            .offset(x: CGFloat(dx) * 2, y: CGFloat(dy) * 2)
                    }
                }
            }
            Text(text)
                .font(font)
                .foregroundColor(c)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Clock router

struct ClockContent: View {
    let date: Date
    @ObservedObject var settings: SettingsManager

    var body: some View {
        switch settings.clockStyle {
        case .digitalModern:  DigitalClockView(date: date, is24Hour: settings.clockIs24Hour, retro: false)
        case .digitalRetro:   DigitalClockView(date: date, is24Hour: settings.clockIs24Hour, retro: true)
        case .analog:         AnalogClockView(date: date, minimal: false)
        case .analogMinimal:  AnalogClockView(date: date, minimal: true)
        case .digitalBold:    DigitalBoldClockView(date: date, is24Hour: settings.clockIs24Hour)
        case .neon:           NeonClockView(date: date, is24Hour: settings.clockIs24Hour)
        case .fuzzy:          FuzzyClockView(date: date)
        case .analogArc:      AnalogArcClockView(date: date)
        }
    }
}

// MARK: - Digital Clock

struct DigitalClockView: View {
    let date: Date
    let is24Hour: Bool
    let retro: Bool

    // Static formatters — created once
    private static let fmt24 = makeFmt("HH:mm:ss")
    private static let fmt12 = makeFmt("hh:mm:ss")
    private static let fmtAM = makeFmt("a")
    private static func makeFmt(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.dateFormat = f; return d
    }

    private var timeStr: String { (is24Hour ? Self.fmt24 : Self.fmt12).string(from: date) }
    private var ampm:    String { is24Hour ? "" : Self.fmtAM.string(from: date) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timeStr)
                .font(retro
                    ? .system(size: 72, weight: .regular, design: .monospaced)
                    : .system(size: 80, weight: .thin,    design: .rounded))
                .monospacedDigit()
                .foregroundColor(retro ? Color(red: 0.2, green: 1.0, blue: 0.4) : .white)
                .shadow(
                    color: retro ? Color.green.opacity(0.5) : .black.opacity(0.25),
                    radius: retro ? 12 : 4
                )

            if !ampm.isEmpty {
                Text(ampm)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 6)
            }
        }
        .padding(retro ? 24 : 0)
        .background {
            if retro {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Analog Clock

struct AnalogClockView: View {
    let date: Date
    let minimal: Bool

    private let size: CGFloat = 200

    private var cal: Calendar { .current }
    private var hour:   Double { Double(cal.component(.hour,   from: date) % 12) + Double(cal.component(.minute, from: date)) / 60 }
    private var minute: Double { Double(cal.component(.minute, from: date)) + Double(cal.component(.second, from: date)) / 60 }
    private var second: Double { Double(cal.component(.second, from: date)) }

    var body: some View {
        ZStack {
            // Dial face
            Circle()
                .fill(Color.white.opacity(minimal ? 0.05 : 0.1))
                .overlay(Circle().stroke(Color.white.opacity(minimal ? 0.15 : 0.35), lineWidth: 1.5))

            // Hour tick marks
            if !minimal {
                ForEach(0..<12, id: \.self) { i in
                    let major = i % 3 == 0
                    Rectangle()
                        .fill(Color.white.opacity(major ? 0.85 : 0.4))
                        .frame(width: major ? 2.5 : 1, height: major ? 14 : 8)
                        .offset(y: -(size / 2 - (major ? 9 : 6)))
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }

            // Hour hand
            ClockHand(length: size * 0.28)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(hour / 12 * 360 - 90))

            // Minute hand
            ClockHand(length: size * 0.38)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(minute / 60 * 360 - 90))

            // Second hand
            ClockHand(length: size * 0.43)
                .stroke(Color.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(second / 60 * 360 - 90))

            // Center pivot
            Circle().fill(Color.white).frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
    }
}

struct ClockHand: Shape {
    let length: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addLine(to: CGPoint(x: c.x + length, y: c.y))
        return p
    }
}

// MARK: - Digital Bold Clock

struct DigitalBoldClockView: View {
    let date: Date
    let is24Hour: Bool

    private static let timeFmt24  = makeFmt("HH:mm")
    private static let timeFmt12  = makeFmt("h:mm")
    private static let secFmt     = makeFmt("ss")
    private static let dateFmt    = makeFmt("EEEE, MMM d")
    private static let ampmFmt    = makeFmt("a")
    private static func makeFmt(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.dateFormat = f; return d
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(is24Hour ? Self.timeFmt24.string(from: date) : Self.timeFmt12.string(from: date))
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.secFmt.string(from: date))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.55))

                    if !is24Hour {
                        Text(Self.ampmFmt.string(from: date))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }

            Text(Self.dateFmt.string(from: date))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .tracking(1.2)
        }
        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 4)
    }
}

// MARK: - Neon Clock

struct NeonClockView: View {
    let date: Date
    let is24Hour: Bool

    private static let timeFmt24 = makeFmt("HH:mm:ss")
    private static let timeFmt12 = makeFmt("hh:mm:ss")
    private static let ampmFmt   = makeFmt("a")
    private static func makeFmt(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.dateFormat = f; return d
    }

    private let cyan  = Color(red: 0.0, green: 0.95, blue: 0.88)
    private let pink  = Color(red: 1.0, green: 0.2,  blue: 0.6)

    var body: some View {
        let timeStr = (is24Hour ? Self.timeFmt24 : Self.timeFmt12).string(from: date)
        let ampm    = is24Hour ? "" : Self.ampmFmt.string(from: date)

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timeStr)
                .font(.system(size: 76, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(cyan)
                .shadow(color: cyan.opacity(0.85), radius: 18)
                .shadow(color: cyan.opacity(0.4),  radius: 36)

            if !ampm.isEmpty {
                Text(ampm)
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .foregroundColor(pink)
                    .shadow(color: pink.opacity(0.85), radius: 14)
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cyan.opacity(0.25), lineWidth: 1)
                }
        }
    }
}

// MARK: - Fuzzy Clock

struct FuzzyClockView: View {
    let date: Date

    private var fuzzyTime: String {
        let cal    = Calendar.current
        let hour   = cal.component(.hour,   from: date)
        let minute = cal.component(.minute, from: date)

        let names = ["twelve","one","two","three","four","five",
                     "six","seven","eight","nine","ten","eleven","twelve"]
        let h = hour % 12
        let n = (hour + 1) % 12

        switch minute {
        case  0...2:  return "\(names[h])\no'clock"
        case  3...7:  return "five past\n\(names[h])"
        case  8...12: return "ten past\n\(names[h])"
        case 13...17: return "quarter past\n\(names[h])"
        case 18...22: return "twenty past\n\(names[h])"
        case 23...27: return "twenty-five past\n\(names[h])"
        case 28...32: return "half past\n\(names[h])"
        case 33...37: return "twenty-five to\n\(names[n])"
        case 38...42: return "twenty to\n\(names[n])"
        case 43...47: return "quarter to\n\(names[n])"
        case 48...52: return "ten to\n\(names[n])"
        case 53...57: return "five to\n\(names[n])"
        default:      return "\(names[n])\no'clock"
        }
    }

    var body: some View {
        Text(fuzzyTime)
            .font(.system(size: 54, weight: .thin, design: .serif))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .shadow(color: .black.opacity(0.45), radius: 10)
    }
}

// MARK: - Analog Arc Clock

/// Arc-sector style: sweeping arcs replace traditional hands.
struct AnalogArcClockView: View {
    let date: Date
    private let size: CGFloat = 200

    private var cal: Calendar { .current }
    private var hourFraction: Double {
        let h = Double(cal.component(.hour,   from: date) % 12)
        let m = Double(cal.component(.minute, from: date))
        return (h + m / 60) / 12
    }
    private var minuteFraction: Double {
        let m = Double(cal.component(.minute, from: date))
        let s = Double(cal.component(.second, from: date))
        return (m + s / 60) / 60
    }
    private var secondFraction: Double {
        Double(cal.component(.second, from: date)) / 60
    }
    private var timeStr: String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"; return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            // Dial background
            Circle()
                .fill(Color.white.opacity(0.07))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))

            // Hour arc — thick blue
            ArcShape(fraction: hourFraction)
                .stroke(Color(red: 0.35, green: 0.6, blue: 1.0).opacity(0.9),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))

            // Minute arc — medium white
            ArcShape(fraction: minuteFraction)
                .stroke(Color.white.opacity(0.75),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))

            // Second arc — thin orange
            ArcShape(fraction: secondFraction)
                .stroke(Color.orange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Digital readout at bottom-center
            Text(timeStr)
                .font(.system(size: 20, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.7))
                .offset(y: size * 0.22)

            // Center pivot
            Circle().fill(Color.white).frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
    }
}

struct ArcShape: Shape {
    let fraction: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 10
        var p = Path()
        p.addArc(center: center,
                 radius: radius,
                 startAngle: .degrees(-90),
                 endAngle:   .degrees(-90 + fraction * 360),
                 clockwise: false)
        return p
    }
}

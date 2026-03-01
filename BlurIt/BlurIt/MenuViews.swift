import SwiftUI
import AppKit

// MARK: - Intensity Slider

struct IntensitySliderView: View {
    @ObservedObject var settings: SettingsManager
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Intensity: \(Int(settings.blurIntensity))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
            HStack(spacing: 8) {
                Image(systemName: "circle.dashed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $settings.blurIntensity, in: 10...100, step: 1)
                    .controlSize(.small)
                    .onChange(of: settings.blurIntensity) { _ in onChange() }
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 4)
        .frame(width: 220)
    }
}

// MARK: - Text Field

struct TextFieldMenuView: View {
    @ObservedObject var settings: SettingsManager
    var onChange: () -> Void

    var body: some View {
        TextField("Optional overlay text…", text: $settings.overlayText)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(width: 220)
            .onChange(of: settings.overlayText) { _ in onChange() }
    }
}

// MARK: - Font Size Slider

struct FontSizeSliderView: View {
    @ObservedObject var settings: SettingsManager
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("A")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Slider(value: $settings.fontSize, in: 12...96, step: 2)
                .controlSize(.small)
                .onChange(of: settings.fontSize) { _ in onChange() }
            Text("A")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(width: 220)
    }
}

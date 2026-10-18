//
//  UtilityButtonsView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Controls-layer chrome, so these use real Liquid Glass (`.buttonStyle(.glass)`)
/// rather than the elevated-panel treatment the telemetry cards use — per
/// Apple's HIG, Liquid Glass belongs on controls, not content.
///
/// Icon-only circular buttons rather than text+icon pills, per the approved
/// mockup — the label lives in `.help()` instead, which iPadOS surfaces as a
/// pointer/trackpad hover tooltip (the touch-equivalent-free affordance for
/// an icon with no inline text) and VoiceOver reads from the `Label`'s title
/// even with `.iconOnly` styling.
struct UtilityButtonsView: View {
    let onZeroYaw: () -> Void
    let onCalibrate: () -> Void

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var scale

    private let baseDiameter: CGFloat = 44

    var body: some View {
        GlassEffectContainer(spacing: 12 * scale) {
            HStack(spacing: 12 * scale) {
                iconButton(systemImage: "location.north.line", label: "Zero Yaw", action: onZeroYaw)
                iconButton(systemImage: "arrow.triangle.2.circlepath", label: "Calibrate", action: onCalibrate)
            }
        }
    }

    private func iconButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: baseDiameter * scale, height: baseDiameter * scale)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(theme.accent)
        .help(label)
    }
}

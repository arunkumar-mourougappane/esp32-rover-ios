//
//  JoystickView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// A stateless 2-axis virtual joystick: it only tracks the knob's visual
/// offset for rendering and reports normalized throttle/steer through
/// closures. It owns no timer and no connection — resending drive commands
/// while held is `RoverConnection`'s job, so this view's lifecycle never
/// affects that resend loop.
///
/// Controls-layer chrome, so base and knob use real Liquid Glass — per
/// Apple's HIG, interactive slider-like controls in the content layer are
/// an explicit exception to "don't use Liquid Glass in the content layer."
struct JoystickView: View {
    var onChange: (_ throttle: Double, _ steer: Double) -> Void
    var onRelease: () -> Void

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var uiScale

    private let baseDiameter: CGFloat = 220
    private let baseKnobDiameter: CGFloat = 84

    @State private var knobOffset: CGSize = .zero
    @State private var isDragging = false

    private var diameter: CGFloat { baseDiameter * uiScale }
    private var knobDiameter: CGFloat { baseKnobDiameter * uiScale }
    private var radius: CGFloat { (diameter - knobDiameter) / 2 }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ZStack {
                Color.clear
                    .frame(width: diameter, height: diameter)
                    .glassEffect(.regular, in: Circle())
                // Crosshair, echoing the dashboard's grid styling.
                Rectangle().fill(theme.dim.opacity(0.25)).frame(width: diameter - 16, height: 1)
                Rectangle().fill(theme.dim.opacity(0.25)).frame(width: 1, height: diameter - 16)
                Color.clear
                    .frame(width: knobDiameter, height: knobDiameter)
                    .glassEffect(.regular.tint(isDragging ? theme.ok : theme.accent).interactive(), in: Circle())
                    .offset(knobOffset)
            }
        }
        .frame(width: diameter, height: diameter)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    let clamped = clampedOffset(for: value.translation)
                    knobOffset = clamped
                    let steer = Double(clamped.width / radius)
                    let throttle = Double(-clamped.height / radius)
                    onChange(throttle, steer)
                }
                .onEnded { _ in
                    isDragging = false
                    knobOffset = .zero
                    onRelease()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Drive joystick")
    }

    private func clampedOffset(for translation: CGSize) -> CGSize {
        let distance = (translation.width * translation.width + translation.height * translation.height).squareRoot()
        guard distance > radius else { return translation }
        let scale = radius / distance
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }
}

#Preview {
    JoystickView(onChange: { _, _ in }, onRelease: {})
        .padding()
        .background(RoverPalette.cyberTeal.background)
        .environment(\.roverPalette, .cyberTeal)
}

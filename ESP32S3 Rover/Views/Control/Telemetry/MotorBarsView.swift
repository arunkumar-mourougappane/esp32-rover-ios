//
//  MotorBarsView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Echoes the rover's commanded left/right motor values (-1...1) back as
/// bars, so the driver can confirm joystick input is actually reaching the
/// motors. Forward fills green, reverse fills amber — matching the tyre
/// fill convention on the rover's own web dashboard.
struct MotorBarsView: View {
    let left: Double
    let right: Double

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var scale

    var body: some View {
        VStack(spacing: 6) {
            Text("Motors").font(.caption).foregroundStyle(theme.dim)
            HStack(spacing: 16 * scale) {
                bar(value: left, label: "L")
                bar(value: right, label: "R")
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func bar(value: Double, label: String) -> some View {
        VStack(spacing: 2) {
            GeometryReader { proxy in
                let height = proxy.size.height
                let mid = height / 2
                let fillHeight = abs(value) * mid
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.background)
                    Rectangle()
                        .fill(value >= 0 ? theme.ok : theme.warn)
                        .frame(height: fillHeight)
                        .offset(y: value >= 0 ? -fillHeight / 2 : fillHeight / 2)
                }
            }
            .frame(maxWidth: 60, maxHeight: .infinity)
            Text(label).font(.caption2).foregroundStyle(theme.text)
            Text(String(format: "%+.0f%%", value * 100))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.dim)
        }
    }
}

#Preview {
    MotorBarsView(left: 0.8, right: -0.3)
        .padding()
        .background(RoverPalette.cyberTeal.background)
        .environment(\.roverPalette, .cyberTeal)
}

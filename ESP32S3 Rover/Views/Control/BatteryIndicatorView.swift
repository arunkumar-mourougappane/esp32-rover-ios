//
//  BatteryIndicatorView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Compact status-bar battery indicator (icon + voltage), replacing the
/// earlier full-size gauge card — a single number doesn't need a whole
/// card's worth of space. Thresholds are a single-cell Li-ion curve
/// (roughly 3.3V empty to 4.2V full), matching the MAX17048 on the rover.
struct BatteryIndicatorView: View {
    let voltage: Double?

    @Environment(\.roverPalette) private var theme

    private let minVolts = 3.3
    private let maxVolts = 4.2

    private var fraction: Double? {
        guard let voltage else { return nil }
        return min(max((voltage - minVolts) / (maxVolts - minVolts), 0), 1)
    }

    private var color: Color {
        guard let fraction else { return theme.dim }
        if fraction < 0.2 { return theme.bad }
        if fraction < 0.4 { return theme.warn }
        return theme.ok
    }

    var body: some View {
        HStack(spacing: 6) {
            Canvas { context, size in
                let bodyRect = CGRect(x: 0, y: 0, width: size.width - 3, height: size.height)
                context.stroke(Path(roundedRect: bodyRect, cornerRadius: 2.5), with: .color(theme.dim), lineWidth: 1)

                let nubRect = CGRect(x: size.width - 3, y: size.height * 0.3, width: 3, height: size.height * 0.4)
                context.fill(Path(roundedRect: nubRect, cornerRadius: 1), with: .color(theme.dim))

                if let fraction {
                    let inset: CGFloat = 2
                    let fillWidth = max(0, (bodyRect.width - inset * 2) * fraction)
                    let fillRect = CGRect(x: inset, y: inset, width: fillWidth, height: bodyRect.height - inset * 2)
                    context.fill(Path(roundedRect: fillRect, cornerRadius: 1), with: .color(color))
                }
            }
            .frame(width: 24, height: 12)

            Text(voltage.map { String(format: "%.2fV", $0) } ?? "n/a")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.dim)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        BatteryIndicatorView(voltage: 3.95)
        BatteryIndicatorView(voltage: 3.4)
        BatteryIndicatorView(voltage: 3.2)
        BatteryIndicatorView(voltage: nil)
    }
    .padding()
    .background(RoverPalette.cyberTeal.background)
    .environment(\.roverPalette, .cyberTeal)
}

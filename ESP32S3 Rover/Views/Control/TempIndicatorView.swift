//
//  TempIndicatorView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Compact status-bar temperature indicator (icon + reading), matching
/// `BatteryIndicatorView`'s footprint. `telemetry.temp` is the MPU6050's
/// own die temperature (see `docs/PROTOCOL.md` in the firmware repo) — not
/// ambient or motor temp, since the rover has no other temp sensor — but
/// it still flags an overheating electronics bay.
struct TempIndicatorView: View {
    let celsius: Double?

    @Environment(\.roverPalette) private var theme

    private let warnThreshold = 50.0
    private let badThreshold = 65.0

    private var color: Color {
        guard let celsius else { return theme.dim }
        if celsius >= badThreshold { return theme.bad }
        if celsius >= warnThreshold { return theme.warn }
        return theme.dim
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "thermometer.medium")
                .font(.caption)
                .foregroundStyle(color)
            Text(celsius.map { String(format: "%.0f°C", $0) } ?? "n/a")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.dim)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        TempIndicatorView(celsius: 32)
        TempIndicatorView(celsius: 55)
        TempIndicatorView(celsius: 70)
        TempIndicatorView(celsius: nil)
    }
    .padding()
    .background(RoverPalette.cyberTeal.background)
    .environment(\.roverPalette, .cyberTeal)
}

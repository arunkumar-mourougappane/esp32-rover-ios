//
//  GMeterView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Lateral/forward g-force meter: concentric rings (0.2g/0.4g/0.6g, matching
/// `rover_tool.py`'s Viz g-meter) with a dot showing the current
/// gravity-compensated acceleration reading.
///
/// Compensation uses `att.roll` for the forward axis and both `att.roll`
/// and `att.pitch` for the lateral axis — the reverse of the usual
/// pitch/roll roles, because on this rover's IMU mounting `roll` reports
/// physical nose-up/down tilt and `pitch` reports physical left/right lean.
/// See the `project-tilt-axis-mapping` note.
///
/// The same physical IMU mounting also swaps the accelerometer's x/y axes:
/// `imu.ay` (not `ax`) responds to forward/backward motion, and `imu.ax`
/// (not `ay`) responds to side-to-side motion — confirmed on hardware after
/// the roll-sign fix made the gauge react to motion but on the wrong screen
/// axis.
///
/// `imu.ax`/`ay` here have already had their slow bias removed by
/// `RoverConnection` (see `IMUBiasFilter`) before this view ever sees them —
/// that's what makes the dot actually rest at (0,0) when stationary.
struct GMeterView: View {
    let imu: Telemetry.IMU
    let attitude: Telemetry.Attitude

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var scale

    private static let gravity = 9.80665
    private let maxG = 0.6

    private var lateralG: Double {
        let rollRadians = attitude.roll * .pi / 180
        let pitchRadians = attitude.pitch * .pi / 180
        return (imu.ax - Self.gravity * cos(rollRadians) * sin(pitchRadians)) / Self.gravity
    }

    private var forwardG: Double {
        let rollRadians = attitude.roll * .pi / 180
        // gx = -g*sin(roll), so the compensation term is ay - gx = ay + g*sin(roll)
        // (lateralG's cos(roll)*sin(pitch) term already carries the correct
        // sign for gy = +g*cos(roll)*sin(pitch), so it doesn't need this flip).
        return (imu.ay + Self.gravity * sin(rollRadians)) / Self.gravity
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("G-Force").font(.caption).foregroundStyle(theme.dim)
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(String(format: "%+.2fg · %+.2fg", lateralG, forwardG))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.dim)
        }
        .padding(10 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2 - 6
        let pixelsPerG = maxRadius / maxG

        for ring in [0.2, 0.4, 0.6] {
            let path = Path(ellipseIn: CGRect(
                x: center.x - ring * pixelsPerG, y: center.y - ring * pixelsPerG,
                width: ring * pixelsPerG * 2, height: ring * pixelsPerG * 2
            ))
            context.stroke(path, with: .color(theme.dim.opacity(0.25)), lineWidth: 1)
        }

        var horizontal = Path()
        horizontal.move(to: CGPoint(x: center.x - maxRadius, y: center.y))
        horizontal.addLine(to: CGPoint(x: center.x + maxRadius, y: center.y))
        context.stroke(horizontal, with: .color(theme.dim.opacity(0.25)), lineWidth: 1)

        var vertical = Path()
        vertical.move(to: CGPoint(x: center.x, y: center.y - maxRadius))
        vertical.addLine(to: CGPoint(x: center.x, y: center.y + maxRadius))
        context.stroke(vertical, with: .color(theme.dim.opacity(0.25)), lineWidth: 1)

        let clampedLateral = min(max(lateralG, -maxG), maxG)
        let clampedForward = min(max(forwardG, -maxG), maxG)
        let dot = CGPoint(x: center.x + clampedLateral * pixelsPerG, y: center.y - clampedForward * pixelsPerG)
        context.fill(Path(ellipseIn: CGRect(x: dot.x - 4.5, y: dot.y - 4.5, width: 9, height: 9)), with: .color(theme.ok))
    }
}

#Preview {
    GMeterView(
        imu: .init(ax: 2.4, ay: -1.0, az: 9.8, gx: 0, gy: 0, gz: 0),
        attitude: .init(pitch: 5, roll: -8, yaw: 0, accPitch: 5, accRoll: -8)
    )
    .padding()
    .background(RoverPalette.cyberTeal.background)
    .environment(\.roverPalette, .cyberTeal)
}

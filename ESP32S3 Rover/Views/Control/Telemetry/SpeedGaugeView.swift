//
//  SpeedGaugeView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Semicircular gauge showing commanded drive power — `max(|left|,|right|)`
/// straight from `motors.left`/`right` (-1..1), no IMU involved. There's no
/// wheel encoder to measure real speed, and double-integrating the
/// accelerometer to estimate it turned out to pick up PWM-correlated noise
/// (motor/driver electrical noise riding the power rail) that had nothing
/// to do with real motion — see `project-no-reliable-speedometer`. This is
/// honest about being commanded power, not speed: it reads the same
/// whether the rover is actually moving or its wheels are stalled.
struct SpeedGaugeView: View {
    /// 0...1, commanded drive power (`max(|left|,|right|)`).
    let powerFraction: Double

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var scale

    private let canvasSize = CGSize(width: 108, height: 64)

    private var fraction: Double {
        min(max(powerFraction, 0), 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("Power").font(.caption)
                Text("(commanded)").font(.caption2)
            }
            .foregroundStyle(theme.dim)
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(String(format: "%.0f%%", fraction * 100))
                .font(.caption2.monospacedDigit().bold())
                .foregroundStyle(theme.text)
        }
        .padding(10 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    /// `t` runs 0...1 from the left end of the semicircle to the right end.
    private func point(at t: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (180 - t * 180) * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }

    private func arcPath(from start: Double, to end: Double, center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        guard end > start else { return path }
        let steps = 24
        for i in 0...steps {
            let t = start + (end - start) * Double(i) / Double(steps)
            let point = point(at: t, center: center, radius: radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        // Canvas's `size` no longer necessarily matches `canvasSize`'s 108:64
        // aspect ratio now that the frame fills its card rather than being
        // fixed — fit-contain the semicircle (uniform scale + center) within
        // whatever box we're actually given, same as SVG's default
        // `preserveAspectRatio="xMidYMid meet"` in the HTML mockup.
        let localScale = min(size.width / canvasSize.width, size.height / canvasSize.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + (canvasSize.height / 2 - 6) * localScale)
        let radius = (min(canvasSize.width / 2, canvasSize.height) - 6) * localScale

        let track = arcPath(from: 0, to: 1, center: center, radius: radius)
        context.stroke(track, with: .color(theme.dim.opacity(0.3)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        if fraction > 0.02 {
            let fill = arcPath(from: 0, to: fraction, center: center, radius: radius)
            context.stroke(fill, with: .color(theme.accent), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }

        for tick in stride(from: 0.0, through: 1.0, by: 0.25) {
            let outer = point(at: tick, center: center, radius: radius)
            let inner = point(at: tick, center: center, radius: radius - 6)
            var line = Path()
            line.move(to: inner)
            line.addLine(to: outer)
            context.stroke(line, with: .color(theme.dim.opacity(0.5)), lineWidth: 1.2)
        }

        let needleTip = point(at: fraction, center: center, radius: radius - 8)
        var needle = Path()
        needle.move(to: center)
        needle.addLine(to: needleTip)
        context.stroke(needle, with: .color(theme.text), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
            with: .color(theme.text)
        )
    }
}

#Preview {
    HStack {
        SpeedGaugeView(powerFraction: 0.34)
        SpeedGaugeView(powerFraction: 0)
        SpeedGaugeView(powerFraction: 1.0)
    }
    .padding()
    .background(RoverPalette.cyberTeal.background)
    .environment(\.roverPalette, .cyberTeal)
}

//
//  HeadingView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Top-down heading/compass panel: a fixed rover body with the compass ring
/// rotating underneath it, wheels tinted by drive direction/speed. This
/// replaces an earlier aircraft-style artificial-horizon gauge — the rover
/// never flies, so the ground-vehicle metaphor already used by the firmware's
/// own web dashboard and `tools/rover_tool.py` Viz class (a rotating compass
/// behind a fixed car icon, tyres filling green/amber for speed) fits far
/// better than a drone/aviation instrument. Yaw is gyro-integrated only on
/// the firmware side, so it drifts — shown as a relative heading, not implied
/// absolute accuracy. Pitch/roll get their own `TiltView` panels alongside
/// this one, so this view only needs yaw plus drive direction for the wheels.
struct HeadingView: View {
    let yaw: Double
    let left: Double
    let right: Double

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var scale

    private let diameter: CGFloat = 96

    var body: some View {
        VStack(spacing: 6) {
            Text("Heading").font(.caption).foregroundStyle(theme.dim)
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Y \(yaw, specifier: "%+.0f")°")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.dim)
        }
        .padding(10 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let localScale = size.width / diameter
        let ringRadius = min(size.width, size.height) / 2 - 12 * localScale

        var ring = Path()
        ring.addEllipse(in: CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
        context.stroke(ring, with: .color(theme.dim.opacity(0.4)), lineWidth: 1)

        // Tick marks rotate under the fixed rover body as yaw changes.
        for tick in stride(from: 0, to: 360, by: 30) {
            let degrees = Double(tick) + yaw
            let radians = degrees * .pi / 180
            let innerRadius = ringRadius - (tick % 90 == 0 ? 9 : 5) * localScale
            let outer = CGPoint(x: center.x + sin(radians) * ringRadius, y: center.y - cos(radians) * ringRadius)
            let inner = CGPoint(x: center.x + sin(radians) * innerRadius, y: center.y - cos(radians) * innerRadius)
            var line = Path()
            line.move(to: inner)
            line.addLine(to: outer)
            context.stroke(line, with: .color(theme.dim.opacity(0.5)), lineWidth: 1)
        }

        // Fixed top-down rover body, nose pointing up (forward).
        let bodyWidth: CGFloat = 20 * localScale
        let bodyLength: CGFloat = 34 * localScale
        let bodyRect = CGRect(x: center.x - bodyWidth / 2, y: center.y - bodyLength / 2, width: bodyWidth, height: bodyLength)
        let body = Path(roundedRect: bodyRect, cornerRadius: 6 * localScale)
        context.fill(body, with: .color(theme.background))
        context.stroke(body, with: .color(theme.accent), lineWidth: 1.5)

        // Wheels flank the body, filled green (forward) or amber (reverse)
        // proportional to commanded speed — same convention as the tyre
        // fill on the rover's own web dashboard.
        wheel(in: &context, center: CGPoint(x: bodyRect.minX - 5 * localScale, y: center.y), value: left, localScale: localScale)
        wheel(in: &context, center: CGPoint(x: bodyRect.maxX + 5 * localScale, y: center.y), value: right, localScale: localScale)

        // Forward-reference pointer at the top of the ring.
        var nose = Path()
        nose.move(to: CGPoint(x: center.x, y: center.y - ringRadius - 8 * localScale))
        nose.addLine(to: CGPoint(x: center.x - 4 * localScale, y: center.y - ringRadius))
        nose.addLine(to: CGPoint(x: center.x + 4 * localScale, y: center.y - ringRadius))
        nose.closeSubpath()
        context.fill(nose, with: .color(theme.accent))
    }

    private func wheel(in context: inout GraphicsContext, center: CGPoint, value: Double, localScale: CGFloat) {
        let wheelRect = CGRect(x: center.x - 3.5 * localScale, y: center.y - 13 * localScale, width: 7 * localScale, height: 26 * localScale)
        context.fill(Path(roundedRect: wheelRect, cornerRadius: 2 * localScale), with: .color(theme.background))
        context.stroke(Path(roundedRect: wheelRect, cornerRadius: 2 * localScale), with: .color(theme.dim.opacity(0.5)), lineWidth: 0.5)

        let fillLength = min(abs(value), 1) * (wheelRect.height / 2)
        guard fillLength >= 1 else { return }
        let fillColor = value >= 0 ? theme.ok : theme.warn
        let fillRect = value >= 0
            ? CGRect(x: wheelRect.minX, y: center.y - fillLength, width: wheelRect.width, height: fillLength)
            : CGRect(x: wheelRect.minX, y: center.y, width: wheelRect.width, height: fillLength)
        context.fill(Path(roundedRect: fillRect, cornerRadius: 2 * localScale), with: .color(fillColor))
    }
}

#Preview {
    HStack(spacing: 10) {
        HeadingView(yaw: 45, left: 0.8, right: -0.3)
        TiltView(orientation: .side, angle: -18)
        TiltView(orientation: .rear, angle: 30)
        MotorBarsView(left: 0.8, right: -0.3)
    }
    .padding()
    .background(RoverPalette.cyberTeal.background)
    .environment(\.roverPalette, .cyberTeal)
}

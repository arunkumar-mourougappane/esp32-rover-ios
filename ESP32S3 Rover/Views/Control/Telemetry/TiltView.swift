//
//  TiltView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Side (nose up/down) or rear (left/right lean) tilt panel: a technical
/// schematic rover silhouette — angular chamfered chassis, wireframe wheels
/// with cross-spokes, a plain diamond sensor-mast marker — leaning on its
/// wheels against a ground line. Deliberately not an aircraft/drone
/// attitude instrument, and deliberately not a rounded "toy car" either;
/// this reads as a CAD/blueprint line drawing instead.
///
/// On this rover's IMU mounting, `att.roll` reports physical nose-up/down
/// tilt and `att.pitch` reports physical left/right lean — the reverse of
/// the firmware/web-dashboard's usual convention. Callers should pass
/// `telemetry.att.roll` for `.side` and `telemetry.att.pitch` for `.rear`.
/// See the `project-tilt-axis-mapping` note.
struct TiltView: View {
    enum Orientation {
        case side, rear

        var title: String {
            switch self {
            case .side: return "Side"
            case .rear: return "Rear"
            }
        }
    }

    let orientation: Orientation
    let angle: Double

    @Environment(\.roverPalette) private var theme
    @Environment(\.roverUIScale) private var scale

    private let canvasSize = CGSize(width: 120, height: 80)

    var body: some View {
        VStack(spacing: 6) {
            Text(orientation.title).font(.caption).foregroundStyle(theme.dim)
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("\(angle, specifier: "%+.0f")°")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.tiltColor(angle))
        }
        .padding(10 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        // All the shape-drawing below uses coordinates for a 120x80
        // reference canvas. `localScale` fit-contains that reference canvas
        // within whatever actual size this Canvas was given (same as SVG's
        // default `preserveAspectRatio="xMidYMid meet"` in the HTML mockup)
        // rather than deriving scale from width alone, so the silhouette
        // stays centered instead of pinned to literal canvas edges when the
        // card's aspect ratio no longer matches the 120:80 reference.
        let localScale = min(size.width / canvasSize.width, size.height / canvasSize.height)
        let groundY = size.height / 2 + (canvasSize.height / 2 - 14) * localScale
        var ground = Path()
        ground.move(to: CGPoint(x: 10 * localScale, y: groundY))
        ground.addLine(to: CGPoint(x: size.width - 10 * localScale, y: groundY))
        context.stroke(ground, with: .color(theme.dim.opacity(0.35)), lineWidth: 1)

        let clampedAngle = max(min(angle, 45), -45)
        let color = theme.tiltColor(angle)
        let pivot = CGPoint(x: size.width / 2, y: groundY)

        context.translateBy(x: pivot.x, y: pivot.y)
        context.rotate(by: .degrees(-clampedAngle))
        context.scaleBy(x: localScale, y: localScale)

        switch orientation {
        case .side:
            var body = Path()
            body.move(to: CGPoint(x: 30, y: -9))
            body.addLine(to: CGPoint(x: 30, y: -18))
            body.addLine(to: CGPoint(x: 18, y: -26))
            body.addLine(to: CGPoint(x: -18, y: -26))
            body.addLine(to: CGPoint(x: -30, y: -18))
            body.addLine(to: CGPoint(x: -30, y: -9))
            body.closeSubpath()
            context.fill(body, with: .color(theme.background.opacity(0.7)))
            context.stroke(body, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))

            wheel(in: &context, center: CGPoint(x: -19, y: -9))
            wheel(in: &context, center: CGPoint(x: 19, y: -9))
            mast(in: &context, from: CGPoint(x: 0, y: -26), to: CGPoint(x: 0, y: -36))

        case .rear:
            var body = Path()
            body.move(to: CGPoint(x: 13, y: -14))
            body.addLine(to: CGPoint(x: 13, y: -22))
            body.addLine(to: CGPoint(x: 7, y: -28))
            body.addLine(to: CGPoint(x: -7, y: -28))
            body.addLine(to: CGPoint(x: -13, y: -22))
            body.addLine(to: CGPoint(x: -13, y: -14))
            body.closeSubpath()
            context.fill(body, with: .color(theme.background.opacity(0.7)))
            context.stroke(body, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))

            wheel(in: &context, center: CGPoint(x: -12, y: -14))
            wheel(in: &context, center: CGPoint(x: 12, y: -14))
            mast(in: &context, from: CGPoint(x: 0, y: -28), to: CGPoint(x: 0, y: -38))
        }
    }

    private func wheel(in context: inout GraphicsContext, center: CGPoint) {
        let rect = CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)
        context.stroke(Path(ellipseIn: rect), with: .color(theme.dim), lineWidth: 1.3)

        var spokes = Path()
        spokes.move(to: CGPoint(x: center.x - 5, y: center.y))
        spokes.addLine(to: CGPoint(x: center.x + 5, y: center.y))
        spokes.move(to: CGPoint(x: center.x, y: center.y - 5))
        spokes.addLine(to: CGPoint(x: center.x, y: center.y + 5))
        context.stroke(spokes, with: .color(theme.dim), lineWidth: 1)
    }

    private func mast(in context: inout GraphicsContext, from: CGPoint, to: CGPoint) {
        var pole = Path()
        pole.move(to: from)
        pole.addLine(to: to)
        context.stroke(pole, with: .color(theme.dim), lineWidth: 1.3)

        var diamond = Path()
        diamond.move(to: CGPoint(x: to.x - 3, y: to.y))
        diamond.addLine(to: CGPoint(x: to.x, y: to.y - 3))
        diamond.addLine(to: CGPoint(x: to.x + 3, y: to.y))
        diamond.addLine(to: CGPoint(x: to.x, y: to.y + 3))
        diamond.closeSubpath()
        context.stroke(diamond, with: .color(theme.dim), lineWidth: 1.3)
    }
}

#Preview {
    HStack(spacing: 12) {
        TiltView(orientation: .side, angle: -30)
        TiltView(orientation: .rear, angle: 18)
    }
    .padding()
    .background(RoverPalette.cyberTeal.background)
    .environment(\.roverPalette, .cyberTeal)
}

//
//  ControlView.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Landscape-only driving screen (see `project-landscape-only`). Layout:
/// a status bar on top, then a joystick/utility-buttons cluster anchored
/// bottom-left (natural thumb reach while gripping an iPad in landscape)
/// alongside a tiered telemetry panel on the right — "Driving" (Heading,
/// Speed, Motors) always visible, "Diagnostics" (Side, Rear, G-Force)
/// dimmer and collapsible, since only the first tier matters continuously
/// while actually driving.
///
/// The whole thing is wrapped in a `GeometryReader` so it's responsive
/// across screen sizes (iPhone landscape, iPad mini, iPad Pro, ...): the
/// controls pane is sized to its own content (joystick hugs the actual
/// left edge for thumb reach, instead of floating in an oversized fixed
/// column) and the telemetry pane claims all remaining width, so its cards
/// actually grow to fill the space instead of leaving a gap. A single
/// `roverUIScale` derived from available height scales the gauges/joystick
/// up on spacious iPads and down on short iPhone-landscape screens.
struct ControlView: View {
    let store: RoverSessionStore

    @Environment(\.roverPalette) private var theme
    @State private var showDiagnostics = true

    private var telemetry: Telemetry? { store.connection.latestTelemetry }

    /// Reference height the fixed point sizes in the gauge views were
    /// designed against (roughly an 11" iPad landscape).
    private let referenceHeight: CGFloat = 760

    var body: some View {
        GeometryReader { proxy in
            let scale = min(max(proxy.size.height / referenceHeight, 0.58), 1.25)

            VStack(spacing: 0) {
                statusBar
                Divider().overlay(theme.dim.opacity(0.15))

                HStack(spacing: 18 * scale) {
                    leftPane(scale: scale)
                    rightPane(scale: scale)
                }
                .padding(18 * scale)
            }
            .environment(\.roverUIScale, scale)
        }
        .background(theme.background)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            Text("Rover")
                .font(.title3.bold())
                .foregroundStyle(theme.text)

            Spacer()

            if telemetry?.failsafe == true {
                Label("Drive failsafe tripped", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(theme.warn)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.warn.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.warn, lineWidth: 1))
            }

            BatteryIndicatorView(voltage: telemetry?.vbat)
            TempIndicatorView(celsius: telemetry?.temp)

            Label(connectionLabel, systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(connectionColor)

            if let uptimeS = telemetry?.uptimeS {
                Text("Uptime \(formattedUptime(uptimeS))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.dim)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var connectionLabel: String {
        switch store.connection.state {
        case .connecting: return "Connecting…"
        case .disconnected: return "Disconnected"
        case .failed: return "Connection lost"
        case .connected:
            guard let clients = telemetry?.clients else { return "Connected" }
            return "Connected · \(clients) \(clients == 1 ? "client" : "clients")"
        }
    }

    private var connectionColor: Color {
        switch store.connection.state {
        case .connected: return theme.dim
        case .connecting: return theme.warn
        case .disconnected, .failed: return theme.bad
        }
    }

    private func formattedUptime(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    // MARK: - Left pane: controls

    private func leftPane(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            Spacer()
            UtilityButtonsView(
                onZeroYaw: { store.connection.sendZeroYaw() },
                onCalibrate: { store.connection.sendCalibrate() }
            )
            JoystickView(
                onChange: { throttle, steer in
                    let (left, right) = DriveMixer.mix(throttle: throttle, steer: steer)
                    store.connection.sendDrive(left: left, right: right)
                },
                onRelease: {
                    store.connection.sendStop()
                }
            )
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 28 * scale) // clearance above the home-indicator gesture area
    }

    // MARK: - Right pane: tiered telemetry

    /// Caps each telemetry row's height instead of letting it grow
    /// unbounded to fill whatever's left — without this, hiding the
    /// diagnostics row just stretches the primary row's cards taller
    /// ("elongating" them) rather than leaving sane-sized cards with the
    /// freed space distributed as breathing room. Flat, not `* scale`, same
    /// as the HTML mockup's `.row { max-height: 320px }`.
    private let rowMaxHeight: CGFloat = 320

    private func rightPane(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            // Leading + trailing spacers center the row block vertically
            // within whatever space is left (mirrors the mockup's
            // `.right-pane { justify-content: center }`) instead of
            // top-packing it and dumping all the slack into one trailing gap.
            Spacer(minLength: 0)

            HStack(spacing: 12 * scale) {
                HeadingView(
                    yaw: telemetry?.att.yaw ?? 0,
                    left: telemetry?.motors.left ?? 0,
                    right: telemetry?.motors.right ?? 0
                )
                SpeedGaugeView(powerFraction: max(abs(telemetry?.motors.left ?? 0), abs(telemetry?.motors.right ?? 0)))
                MotorBarsView(
                    left: telemetry?.motors.left ?? 0,
                    right: telemetry?.motors.right ?? 0
                )
            }
            .frame(maxWidth: .infinity, maxHeight: rowMaxHeight)

            HStack {
                Text("Diagnostics")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.dim)
                    .textCase(.uppercase)
                Spacer()
                Button(showDiagnostics ? "Hide" : "Show") {
                    withAnimation { showDiagnostics.toggle() }
                }
                .font(.caption.bold())
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.dim.opacity(0.14), in: Capsule())
                .overlay(Capsule().strokeBorder(theme.dim.opacity(0.22), lineWidth: 1))
            }

            if showDiagnostics {
                HStack(spacing: 12 * scale) {
                    // On this rover's IMU mounting, `roll` reports physical
                    // nose-up/down tilt and `pitch` reports physical
                    // left/right lean — see project-tilt-axis-mapping.
                    TiltView(orientation: .side, angle: telemetry?.att.roll ?? 0)
                    TiltView(orientation: .rear, angle: telemetry?.att.pitch ?? 0)
                    GMeterView(
                        imu: telemetry?.imu ?? Telemetry.IMU(ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0),
                        attitude: telemetry?.att ?? Telemetry.Attitude(pitch: 0, roll: 0, yaw: 0, accPitch: 0, accRoll: 0)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: rowMaxHeight)
                .opacity(0.85)
                .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ControlView(store: RoverSessionStore())
        .environment(\.roverPalette, .cyberTeal)
}

#Preview("Daylight") {
    ControlView(store: RoverSessionStore())
        .environment(\.roverPalette, .daylight)
}

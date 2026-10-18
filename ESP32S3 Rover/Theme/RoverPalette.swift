//
//  RoverPalette.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Dual color palette for the driving/control screen: "Cyber Teal" for dark
/// mode, "Daylight" for light mode. Daylight exists specifically because the
/// rover is driven outdoors in direct sunlight, where dark/OLED-style UIs
/// wash out — chosen over `RoverTheme`'s single fixed dark palette (still
/// used by the pairing/setup screens) after reviewing an interactive
/// palette mockup. Injected via `\.roverPalette` so it follows the system's
/// light/dark appearance rather than being forced.
struct RoverPalette: Equatable {
    let background: Color
    let surface: Color
    let dim: Color
    let ok: Color
    let warn: Color
    let bad: Color
    let accent: Color
    let text: Color

    /// Matches rover_tool.py's `_tilt_color`: bad past 35°, warn past 20°.
    func tiltColor(_ degrees: Double) -> Color {
        let magnitude = abs(degrees)
        if magnitude > 35 { return bad }
        if magnitude > 20 { return warn }
        return ok
    }

    static let cyberTeal = RoverPalette(
        background: Color(hex: 0x071019),
        surface: Color(hex: 0x132736),
        dim: Color(hex: 0x5b89a0),
        ok: Color(hex: 0x2dd9c4),
        warn: Color(hex: 0xf2b945),
        bad: Color(hex: 0xff3d6b),
        accent: Color(hex: 0x39e6e6),
        text: .white
    )

    static let daylight = RoverPalette(
        background: Color(hex: 0xeef1f4),
        surface: Color(hex: 0xffffff),
        dim: Color(hex: 0x5b6472),
        ok: Color(hex: 0x1a7f4e),
        warn: Color(hex: 0xb45309),
        bad: Color(hex: 0xc0262b),
        accent: Color(hex: 0x0a66c2),
        text: Color(hex: 0x12161c)
    )
}

private struct RoverPaletteKey: EnvironmentKey {
    static let defaultValue = RoverPalette.cyberTeal
}

extension EnvironmentValues {
    var roverPalette: RoverPalette {
        get { self[RoverPaletteKey.self] }
        set { self[RoverPaletteKey.self] = newValue }
    }
}

/// Uniform scale factor for the driving screen's gauges/joystick, derived
/// from available height so the layout adapts between a short iPhone
/// landscape screen and a tall iPad one, rather than using one fixed size
/// and either wasting space or overflowing. See `ControlView`.
private struct RoverUIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var roverUIScale: CGFloat {
        get { self[RoverUIScaleKey.self] }
        set { self[RoverUIScaleKey.self] = newValue }
    }
}

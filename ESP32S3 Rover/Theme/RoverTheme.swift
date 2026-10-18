//
//  RoverTheme.swift
//  ESP32S3 Rover
//

import SwiftUI

/// Shared color palette, lifted verbatim from the rover firmware's own web
/// dashboard and `tools/rover_tool.py` Viz class, so the iOS app's telemetry
/// screens look like a natural member of the same family as the rover's
/// existing web dashboard and Python GUI rather than a one-off palette.
enum RoverTheme {
    static let background = Color(hex: 0x0f1115)
    static let surface = Color(hex: 0x2a2f3a)
    static let dim = Color(hex: 0x8a93a6)

    static let ok = Color(hex: 0x3ddc84)
    static let warn = Color(hex: 0xffb74d)
    static let bad = Color(hex: 0xff5c5c)
    static let accent = Color(hex: 0x4da6ff)

    /// Matches rover_tool.py's `_tilt_color`: bad past 35°, warn past 20°.
    static func tiltColor(_ degrees: Double) -> Color {
        let magnitude = abs(degrees)
        if magnitude > 35 { return bad }
        if magnitude > 20 { return warn }
        return ok
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

//
//  DriveMixer.swift
//  ESP32S3 Rover
//

import Foundation

/// Arcade-style throttle/steer mixing into independent left/right drive
/// values, kept bit-compatible with the proven reference client's
/// `drive_tick()` in `tools/rover_tool.py`.
nonisolated enum DriveMixer {
    static func mix(throttle: Double, steer: Double) -> (left: Double, right: Double) {
        let left = throttle + steer
        let right = throttle - steer
        let scale = max(1.0, abs(left), abs(right))
        return (left / scale, right / scale)
    }
}

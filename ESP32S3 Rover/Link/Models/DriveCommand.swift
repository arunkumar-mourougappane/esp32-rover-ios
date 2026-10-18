//
//  DriveCommand.swift
//  ESP32S3 Rover
//

import Foundation

/// JSON commands the app sends to the rover over the WebSocket link. See
/// `onWsEvent`/`handleCommand` in the firmware's `src/main.cpp`.
nonisolated enum DriveCommand: Encodable, Equatable {
    case drive(left: Double, right: Double)
    case stop
    case zeroYaw
    case calibrate

    private enum CodingKeys: String, CodingKey {
        case cmd, left, right
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .drive(let left, let right):
            try container.encode("drive", forKey: .cmd)
            try container.encode(left, forKey: .left)
            try container.encode(right, forKey: .right)
        case .stop:
            try container.encode("stop", forKey: .cmd)
        case .zeroYaw:
            try container.encode("zero_yaw", forKey: .cmd)
        case .calibrate:
            try container.encode("calibrate", forKey: .cmd)
        }
    }
}

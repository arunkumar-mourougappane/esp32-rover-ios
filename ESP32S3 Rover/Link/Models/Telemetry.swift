//
//  Telemetry.swift
//  ESP32S3 Rover
//

import Foundation

/// One telemetry snapshot broadcast by the rover at 20 Hz over the WebSocket
/// link. Field names and shape match the firmware's `buildTelemetry()` in
/// `src/main.cpp` exactly.
nonisolated struct Telemetry: Codable, Equatable {
    struct IMU: Codable, Equatable {
        let ax: Double
        let ay: Double
        let az: Double
        let gx: Double
        let gy: Double
        let gz: Double
    }

    struct Attitude: Codable, Equatable {
        let pitch: Double
        let roll: Double
        let yaw: Double
        /// Accelerometer-only angles, for comparison with the fused values.
        /// Noisy and wrong under acceleration.
        let accPitch: Double
        let accRoll: Double

        enum CodingKeys: String, CodingKey {
            case pitch, roll, yaw
            case accPitch = "acc_pitch"
            case accRoll = "acc_roll"
        }
    }

    /// Firmware's complementary-filter state: how much the accelerometer is
    /// trusted this sample, and whether the rover is stationary (gyro bias
    /// tracking, yaw frozen).
    struct FilterState: Codable, Equatable {
        let trust: Double
        let still: Bool
    }

    struct Motors: Codable, Equatable {
        let left: Double
        let right: Double
        let pwm: [Int]
    }

    struct PairingInfo: Codable, Equatable {
        let open: Bool
        let secs: Int
    }

    let seq: Int
    let imu: IMU
    let att: Attitude
    let filt: FilterState
    let motors: Motors
    let temp: Double?
    let vbat: Double?
    let failsafe: Bool
    let clients: Int
    let uptimeS: Int
    let heap: Int
    let pairing: PairingInfo

    enum CodingKeys: String, CodingKey {
        case seq, imu, att, filt, motors, temp, vbat, failsafe, clients
        case uptimeS = "uptime_s"
        case heap, pairing
    }
}

//
//  IMUBiasFilter.swift
//  ESP32S3 Rover
//

import Foundation

/// Tracks slow-moving bias on the accelerometer's `ax`/`ay` axes and removes
/// it from every telemetry tick, so `GMeterView` reads a debiased signal.
/// The firmware's `calibrate` command only zeroes gyro bias
/// (`imu::calibrate()` in the esp32s3-rover firmware) — it never touches
/// the accelerometer, so without this the G-meter dot never rests at
/// (0,0). See project-imu-bias-filtering-todo.
///
/// Bias only updates while `telemetry.filt.still` is true: the firmware's
/// own debounced "truly at rest" signal (motors idle, gyro quiet, |a| near
/// 1g, all held for a beat) — the same window it uses to track its own
/// gyro bias. The time constant mirrors the firmware's gyro bias tracking
/// (`BIAS_RATE` in `src/imu.cpp`), since it's the same physical sensor.
struct IMUBiasFilter {
    private static let timeConstant = 2.5

    private var biasX = 0.0
    private var biasY = 0.0
    private var lastUpdate: Date?

    /// Feeds one telemetry snapshot in; returns its IMU reading with the
    /// tracked `ax`/`ay` bias removed.
    mutating func update(with telemetry: Telemetry, now: Date = Date()) -> Telemetry.IMU {
        defer { lastUpdate = now }
        let imu = telemetry.imu

        if telemetry.filt.still, let lastUpdate {
            let dt = now.timeIntervalSince(lastUpdate)
            if dt > 0 {
                let alpha = min(dt / Self.timeConstant, 1)
                biasX += alpha * (imu.ax - biasX)
                biasY += alpha * (imu.ay - biasY)
            }
        }

        return Telemetry.IMU(ax: imu.ax - biasX, ay: imu.ay - biasY, az: imu.az, gx: imu.gx, gy: imu.gy, gz: imu.gz)
    }
}

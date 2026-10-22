//
//  IMUBiasFilterTests.swift
//  ESP32S3 RoverTests
//

import Foundation
import Testing
@testable import ESP32S3_Rover

struct IMUBiasFilterTests {
    private func makeTelemetry(ax: Double, ay: Double, still: Bool) -> Telemetry {
        Telemetry(
            seq: 0,
            imu: .init(ax: ax, ay: ay, az: 9.8, gx: 0, gy: 0, gz: 0),
            att: .init(pitch: 0, roll: 0, yaw: 0, accPitch: 0, accRoll: 0),
            filt: .init(trust: 1, still: still),
            motors: .init(left: 0, right: 0, pwm: [0, 0, 0, 0]),
            temp: nil,
            vbat: nil,
            failsafe: false,
            clients: 1,
            uptimeS: 0,
            heap: 0,
            pairing: .init(open: false, secs: 0)
        )
    }

    @Test func biasDoesNotMoveWhileDriving() {
        var filter = IMUBiasFilter()
        var now = Date()
        var last: Telemetry.IMU?
        for _ in 0..<10 {
            now = now.addingTimeInterval(1)
            last = filter.update(with: makeTelemetry(ax: 5, ay: -3, still: false), now: now)
        }
        // No stationary window ever occurred, so nothing should be subtracted.
        #expect(last?.ax == 5)
        #expect(last?.ay == -3)
    }

    @Test func biasConvergesTowardReadingWhileStill() {
        var filter = IMUBiasFilter()
        var now = Date()
        var last: Telemetry.IMU?
        for _ in 0..<10 {
            now = now.addingTimeInterval(1)
            last = filter.update(with: makeTelemetry(ax: 0.3, ay: -0.2, still: true), now: now)
        }
        // After several seconds at rest, the tracked bias should have
        // caught up to the (constant) raw reading, leaving ~0 behind.
        #expect(abs(last!.ax) < 0.01)
        #expect(abs(last!.ay) < 0.01)
    }

    @Test func learnedBiasStillAppliesOnceDrivingStarts() {
        var filter = IMUBiasFilter()
        var now = Date()
        for _ in 0..<10 {
            now = now.addingTimeInterval(1)
            _ = filter.update(with: makeTelemetry(ax: 0.3, ay: -0.2, still: true), now: now)
        }
        now = now.addingTimeInterval(1)
        let driving = filter.update(with: makeTelemetry(ax: 0.3, ay: -0.2, still: false), now: now)
        // The bias learned at rest keeps being subtracted after motors
        // start — this is the whole point: GMeterView reads the debiased
        // value while actually driving, not just at rest.
        #expect(abs(driving.ax) < 0.01)
        #expect(abs(driving.ay) < 0.01)
    }
}

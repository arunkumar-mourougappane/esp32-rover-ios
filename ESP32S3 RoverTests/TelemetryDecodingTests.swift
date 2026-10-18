//
//  TelemetryDecodingTests.swift
//  ESP32S3 RoverTests
//

import Foundation
import Testing
@testable import ESP32S3_Rover

struct TelemetryDecodingTests {
    // Shaped exactly like the firmware's buildTelemetry() output in src/main.cpp.
    static let json = """
    {
      "seq": 42,
      "imu": {"ax": 0.12, "ay": -0.05, "az": 9.78, "gx": 1.1, "gy": -0.4, "gz": 0.0},
      "att": {"pitch": -2.3, "roll": 0.5, "yaw": 178.4, "acc_pitch": -2.1, "acc_roll": 0.6},
      "filt": {"trust": 1.0, "still": true},
      "motors": {"left": 0.75, "right": -0.5, "pwm": [512, 0, 0, 256]},
      "temp": null,
      "vbat": null,
      "failsafe": false,
      "clients": 1,
      "uptime_s": 3600,
      "heap": 123456,
      "pairing": {"open": true, "secs": 42}
    }
    """

    @Test func decodesAllFields() throws {
        let telemetry = try JSONDecoder().decode(Telemetry.self, from: Data(Self.json.utf8))

        #expect(telemetry.seq == 42)
        #expect(telemetry.imu.ax == 0.12)
        #expect(telemetry.imu.gz == 0.0)
        #expect(telemetry.att.yaw == 178.4)
        #expect(telemetry.att.accPitch == -2.1)
        #expect(telemetry.att.accRoll == 0.6)
        #expect(telemetry.filt.trust == 1.0)
        #expect(telemetry.filt.still == true)
        #expect(telemetry.motors.left == 0.75)
        #expect(telemetry.motors.right == -0.5)
        #expect(telemetry.motors.pwm == [512, 0, 0, 256])
        #expect(telemetry.temp == nil)
        #expect(telemetry.vbat == nil)
        #expect(telemetry.failsafe == false)
        #expect(telemetry.clients == 1)
        #expect(telemetry.uptimeS == 3600)
        #expect(telemetry.heap == 123456)
        #expect(telemetry.pairing.open == true)
        #expect(telemetry.pairing.secs == 42)
    }

    @Test func decodesPresentOptionalFields() throws {
        let json = Self.json
            .replacingOccurrences(of: "\"temp\": null", with: "\"temp\": 24.5")
            .replacingOccurrences(of: "\"vbat\": null", with: "\"vbat\": 3.98")
        let telemetry = try JSONDecoder().decode(Telemetry.self, from: Data(json.utf8))
        #expect(telemetry.temp == 24.5)
        #expect(telemetry.vbat == 3.98)
    }
}

//
//  DriveCommandTests.swift
//  ESP32S3 RoverTests
//

import Foundation
import Testing
@testable import ESP32S3_Rover

struct DriveCommandTests {
    private func decodeObject(_ command: DriveCommand) throws -> [String: Any] {
        let data = try JSONEncoder().encode(command)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try #require(object)
    }

    @Test func driveEncodesCmdLeftRight() throws {
        let object = try decodeObject(.drive(left: 0.5, right: -0.25))
        #expect(object["cmd"] as? String == "drive")
        #expect(object["left"] as? Double == 0.5)
        #expect(object["right"] as? Double == -0.25)
        #expect(object.count == 3)
    }

    @Test func stopEncodesOnlyCmd() throws {
        let object = try decodeObject(.stop)
        #expect(object["cmd"] as? String == "stop")
        #expect(object.count == 1)
    }

    @Test func zeroYawEncodesOnlyCmd() throws {
        let object = try decodeObject(.zeroYaw)
        #expect(object["cmd"] as? String == "zero_yaw")
        #expect(object.count == 1)
    }

    @Test func calibrateEncodesOnlyCmd() throws {
        let object = try decodeObject(.calibrate)
        #expect(object["cmd"] as? String == "calibrate")
        #expect(object.count == 1)
    }
}

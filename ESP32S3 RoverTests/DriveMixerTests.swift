//
//  DriveMixerTests.swift
//  ESP32S3 RoverTests
//

import Testing
@testable import ESP32S3_Rover

struct DriveMixerTests {
    @Test(arguments: [
        (throttle: 1.0, steer: 0.0, left: 1.0, right: 1.0),
        (throttle: -1.0, steer: 0.0, left: -1.0, right: -1.0),
        (throttle: 0.0, steer: 1.0, left: 1.0, right: -1.0),
        (throttle: 0.0, steer: -1.0, left: -1.0, right: 1.0),
        (throttle: 1.0, steer: 1.0, left: 1.0, right: 0.0),
        (throttle: 0.0, steer: 0.0, left: 0.0, right: 0.0),
    ])
    func mixMatchesReferenceImplementation(case testCase: (throttle: Double, steer: Double, left: Double, right: Double)) {
        let result = DriveMixer.mix(throttle: testCase.throttle, steer: testCase.steer)
        #expect(abs(result.left - testCase.left) < 0.0001)
        #expect(abs(result.right - testCase.right) < 0.0001)
    }

    @Test func mixScalesDownToStayWithinRange() {
        // t: -1, s: 0.5 -> left -0.5, right -1.5, scaled by max(1, 1.5) = 1.5
        let result = DriveMixer.mix(throttle: -1.0, steer: 0.5)
        #expect(abs(result.left - (-0.5 / 1.5)) < 0.0001)
        #expect(abs(result.right - (-1.0)) < 0.0001)
    }

    @Test func mixNeverExceedsUnitRange() {
        let result = DriveMixer.mix(throttle: 1.0, steer: 1.0)
        #expect(abs(result.left) <= 1.0)
        #expect(abs(result.right) <= 1.0)
    }
}

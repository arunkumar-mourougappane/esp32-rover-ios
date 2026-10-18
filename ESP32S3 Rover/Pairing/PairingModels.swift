//
//  PairingModels.swift
//  ESP32S3 Rover
//

import Foundation

/// Wi-Fi credentials handed over by the rover after a successful BLE pairing
/// handshake. Field names match the firmware's `encryptCreds` JSON verbatim.
nonisolated struct RoverCredentials: Codable, Equatable {
    let ssid: String
    let pass: String
    let ip: String
    let http: Int
    let ws: Int
}

nonisolated enum PairingStatusCode: UInt8 {
    case waiting = 0
    case ok = 1
    case badPin = 2
    case locked = 3
}

nonisolated enum PairingError: LocalizedError, Equatable {
    case bluetoothUnavailable
    case serviceNotFound
    case characteristicsMissing
    case wrongPin(triesLeft: Int)
    case lockedOut
    case malformedCredentials
    case disconnected
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is unavailable. Check Settings and try again."
        case .serviceNotFound:
            return "Could not find the rover's pairing service."
        case .characteristicsMissing:
            return "The rover's pairing service is missing expected characteristics."
        case .wrongPin(let triesLeft):
            return "Wrong PIN. \(triesLeft) \(triesLeft == 1 ? "try" : "tries") left."
        case .lockedOut:
            return "Pairing locked out after too many wrong PINs. Press BOOT on the rover to reopen pairing."
        case .malformedCredentials:
            return "Received malformed credentials from the rover."
        case .disconnected:
            return "The rover disconnected before pairing finished."
        case .timeout:
            return "Pairing timed out."
        }
    }
}

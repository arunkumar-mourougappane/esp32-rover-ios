//
//  WiFiProvisioner.swift
//  ESP32S3 Rover
//

import Foundation
import Observation

enum WiFiJoinError: LocalizedError, Equatable {
    case connectivityTimeout

    var errorDescription: String? {
        "Could not reach the rover. Make sure your phone has joined the rover's Wi-Fi network, then try again."
    }
}

/// Confirms the phone can actually reach the rover after the user has
/// manually joined its Wi-Fi network from Settings. Auto-joining via
/// `NEHotspotConfiguration` would need the paid Apple Developer Program's
/// Hotspot Configuration capability, which isn't available to personal/free
/// development teams, so the app asks the user to join manually instead.
@Observable
final class WiFiProvisioner {
    private(set) var isJoined = false

    func verifyReachable(ip: String, httpPort: Int, timeout: TimeInterval = 6) async throws {
        guard let url = URL(string: "http://\(ip):\(httpPort)/json") else {
            throw WiFiJoinError.connectivityTimeout
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        do {
            _ = try await session.data(from: url)
            isJoined = true
        } catch {
            throw WiFiJoinError.connectivityTimeout
        }
    }
}

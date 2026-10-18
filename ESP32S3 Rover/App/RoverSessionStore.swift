//
//  RoverSessionStore.swift
//  ESP32S3 Rover
//

import Foundation
import Observation

/// Top-level state machine tying BLE pairing, Wi-Fi provisioning, and the
/// WebSocket control link together. Owns one instance each of the three
/// managers for the app's lifetime; create exactly once (e.g. as `@State` in
/// `RootView`) so the drive-resend timer and BLE central survive view
/// re-renders untouched.
@MainActor
@Observable
final class RoverSessionStore {
    enum Phase: Equatable {
        case scanning
        case pairing(PairingManager.RoverPeripheral)
        case joiningWiFi(RoverCredentials)
        case connectingLink(RoverCredentials)
        case driving(RoverCredentials)
        case error(String)
    }

    private(set) var phase: Phase = .scanning
    private(set) var wifiVerificationError: String?

    let pairingManager = PairingManager()
    let wifiProvisioner = WiFiProvisioner()
    let connection = RoverConnection()

    init() {
        // The connection can die after the UI has already moved on to the
        // driving screen (e.g. the phone roams off the rover's Wi-Fi) — fall
        // back to the error screen rather than leaving `ControlView` up
        // showing a stale, falsely "connected" status bar.
        connection.onStateChange = { [weak self] state in
            guard case .failed(let message) = state else { return }
            self?.phase = .error(message)
        }
    }

    func startScan() {
        pairingManager.startScan()
    }

    func pair(with peripheral: PairingManager.RoverPeripheral, pin: String) async {
        phase = .pairing(peripheral)
        pairingManager.stopScan()
        do {
            let credentials = try await pairingManager.pair(with: peripheral, pin: pin)
            phase = .joiningWiFi(credentials)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Called once the user says they've manually joined the rover's Wi-Fi
    /// network from Settings (auto-join via `NEHotspotConfiguration` needs
    /// the paid Apple Developer Program's Hotspot Configuration capability,
    /// unavailable to personal/free teams). Verifies reachability and, on
    /// success, proceeds to the WebSocket link.
    func confirmWiFiJoined() async {
        guard case .joiningWiFi(let credentials) = phase else { return }
        wifiVerificationError = nil
        do {
            try await wifiProvisioner.verifyReachable(ip: credentials.ip, httpPort: credentials.http)
            phase = .connectingLink(credentials)
            connection.connect(ip: credentials.ip, wsPort: credentials.ws)
            phase = .driving(credentials)
        } catch {
            wifiVerificationError = error.localizedDescription
        }
    }

    func retry() {
        connection.disconnect()
        wifiVerificationError = nil
        phase = .scanning
        pairingManager.startScan()
    }
}

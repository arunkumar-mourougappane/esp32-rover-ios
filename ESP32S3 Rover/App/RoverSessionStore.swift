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

    /// Credentials from the most recent successful pairing, kept around so
    /// a dropped link (e.g. the watchdog firing on a Wi-Fi blip) can
    /// `reconnect()` straight back to the WebSocket instead of forcing a
    /// full BLE re-pair for something that never needed one.
    private(set) var lastCredentials: RoverCredentials?

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
            lastCredentials = credentials
            phase = .driving(credentials)
        } catch {
            wifiVerificationError = error.localizedDescription
        }
    }

    /// Reconnects using the last successful pairing's credentials, skipping
    /// BLE pairing entirely — for when the link merely dropped (e.g. the
    /// `RoverConnection` watchdog caught a Wi-Fi blip), not when the rover
    /// itself needs re-pairing. Falls back to `retry()` if there's nothing
    /// to reconnect to.
    func reconnect() async {
        guard let credentials = lastCredentials else {
            retry()
            return
        }
        phase = .connectingLink(credentials)
        do {
            try await wifiProvisioner.verifyReachable(ip: credentials.ip, httpPort: credentials.http)
            connection.connect(ip: credentials.ip, wsPort: credentials.ws)
            phase = .driving(credentials)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func retry() {
        connection.disconnect()
        wifiVerificationError = nil
        lastCredentials = nil
        phase = .scanning
        pairingManager.startScan()
    }
}

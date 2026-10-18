//
//  RoverConnection.swift
//  ESP32S3 Rover
//

import Foundation
import Observation

/// Owns the WebSocket link to the rover: receives telemetry, sends drive /
/// utility commands, and keeps resending the latest drive command often
/// enough to stay under the firmware's 400ms drive failsafe
/// (`DRIVE_TIMEOUT_MS` in `src/config.h`). This is a long-lived reference
/// type owned once by `RoverSessionStore`, so the resend loop's lifetime is
/// independent of any view's lifecycle.
@MainActor
@Observable
final class RoverConnection {
    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    private(set) var state: State = .disconnected {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }
    private(set) var latestTelemetry: Telemetry?

    /// Fires on every state transition. `RoverSessionStore` uses this to
    /// fall back to the error screen if the link dies (e.g. the watchdog
    /// below) after the UI already moved on to the driving screen.
    var onStateChange: ((State) -> Void)?

    private var biasFilter = IMUBiasFilter()

    /// How often the latest drive command is resent while driving. Well
    /// under the firmware's 400ms failsafe window.
    private static let driveResendInterval = Duration.milliseconds(150)

    /// Telemetry arrives at a nominal 20 Hz (every 50ms). If nothing's been
    /// heard for this long — e.g. the phone silently roamed off the rover's
    /// Wi-Fi onto another network — treat the link as dead instead of
    /// trusting `URLSessionWebSocketTask.receive()` to ever notice (on a
    /// Wi-Fi handoff it can simply hang with no error). See
    /// project-realtime-connectivity-watchdog.
    private static let telemetryStaleTimeout = TimeInterval(3)
    private static let watchdogInterval = Duration.milliseconds(500)

    private let session = URLSession(configuration: .default)
    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var driveLoop: Task<Void, Never>?
    private var watchdogLoop: Task<Void, Never>?
    private var lastDrive: DriveCommand?
    private var isDriving = false
    private var lastTelemetryAt: Date?

    func connect(ip: String, wsPort: Int) {
        guard let url = URL(string: "ws://\(ip):\(wsPort)/") else {
            state = .failed("Invalid rover address.")
            return
        }
        state = .connecting
        let webSocketTask = session.webSocketTask(with: url)
        task = webSocketTask
        webSocketTask.resume()
        lastTelemetryAt = Date()
        startReceiveLoop()
        startWatchdog()
    }

    func disconnect() {
        teardown()
        state = .disconnected
    }

    private func teardown() {
        isDriving = false
        driveLoop?.cancel()
        driveLoop = nil
        watchdogLoop?.cancel()
        watchdogLoop = nil
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        biasFilter = IMUBiasFilter()
        lastTelemetryAt = nil
    }

    func sendDrive(left: Double, right: Double) {
        let command = DriveCommand.drive(left: left, right: right)
        lastDrive = command
        isDriving = true
        enqueue(command)
        startDriveLoopIfNeeded()
    }

    func sendStop() {
        isDriving = false
        lastDrive = nil
        enqueue(.stop)
    }

    func sendZeroYaw() {
        enqueue(.zeroYaw)
    }

    func sendCalibrate() {
        enqueue(.calibrate)
    }

    private func enqueue(_ command: DriveCommand) {
        guard let data = try? JSONEncoder().encode(command),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func startDriveLoopIfNeeded() {
        guard driveLoop == nil else { return }
        driveLoop = Task { [weak self] in
            while let self, self.isDriving {
                try? await Task.sleep(for: Self.driveResendInterval)
                guard self.isDriving, let command = self.lastDrive else { break }
                self.enqueue(command)
            }
            self?.driveLoop = nil
        }
    }

    private func startReceiveLoop() {
        receiveLoop = Task { [weak self] in
            guard let self else { return }
            while let task = self.task, !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    if case .string(let text) = message,
                       let data = text.data(using: .utf8),
                       let rawTelemetry = try? JSONDecoder().decode(Telemetry.self, from: data) {
                        // Debias ax/ay before anything else sees this tick —
                        // see IMUBiasFilter for why the firmware's own
                        // calibration doesn't already do this.
                        let debiasedIMU = self.biasFilter.update(with: rawTelemetry)
                        let telemetry = Telemetry(
                            seq: rawTelemetry.seq,
                            imu: debiasedIMU,
                            att: rawTelemetry.att,
                            filt: rawTelemetry.filt,
                            motors: rawTelemetry.motors,
                            temp: rawTelemetry.temp,
                            vbat: rawTelemetry.vbat,
                            failsafe: rawTelemetry.failsafe,
                            clients: rawTelemetry.clients,
                            uptimeS: rawTelemetry.uptimeS,
                            heap: rawTelemetry.heap,
                            pairing: rawTelemetry.pairing
                        )
                        self.lastTelemetryAt = Date()
                        self.latestTelemetry = telemetry
                        self.state = .connected
                    }
                } catch {
                    self.teardown()
                    self.state = .failed(error.localizedDescription)
                    break
                }
            }
        }
    }

    /// Passively watches for telemetry going stale, since a Wi-Fi handoff
    /// away from the rover's own AP doesn't reliably make
    /// `URLSessionWebSocketTask.receive()` throw — it can just stop
    /// delivering anything while the task sits there looking "connected".
    private func startWatchdog() {
        watchdogLoop = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: Self.watchdogInterval)
                guard !Task.isCancelled else { break }
                guard let lastTelemetryAt = self.lastTelemetryAt,
                      Date().timeIntervalSince(lastTelemetryAt) > Self.telemetryStaleTimeout else { continue }
                self.teardown()
                self.state = .failed("Lost connection to the rover — check you're still on its Wi-Fi network.")
                break
            }
        }
    }
}

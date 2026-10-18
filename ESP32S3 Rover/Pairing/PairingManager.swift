//
//  PairingManager.swift
//  ESP32S3 Rover
//

import CoreBluetooth
import Foundation
import Observation

/// Drives the rover's BLE pairing handshake: scan, connect, read the
/// challenge nonce, prove knowledge of the PIN, and read back the encrypted
/// Wi-Fi credentials. Protocol reference: esp32s3-rover firmware's
/// `src/pairing.cpp` and `tools/rover_tool.py`.
@Observable
final class PairingManager: NSObject {
    struct RoverPeripheral: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
    }

    private(set) var discovered: [RoverPeripheral] = []
    private(set) var bluetoothReady = false
    private var isScanningRequested = false

    private static let serviceUUID = CBUUID(string: "7D1C0001-5A3E-4B8F-9A62-3C5E1F0A9B10")
    private static let chalUUID = CBUUID(string: "7D1C0002-5A3E-4B8F-9A62-3C5E1F0A9B10")
    private static let authUUID = CBUUID(string: "7D1C0003-5A3E-4B8F-9A62-3C5E1F0A9B10")
    private static let statusUUID = CBUUID(string: "7D1C0004-5A3E-4B8F-9A62-3C5E1F0A9B10")
    private static let credUUID = CBUUID(string: "7D1C0005-5A3E-4B8F-9A62-3C5E1F0A9B10")

    private var central: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?

    private var chalChar: CBCharacteristic?
    private var authChar: CBCharacteristic?
    private var statusChar: CBCharacteristic?
    private var credChar: CBCharacteristic?

    private var pin = ""
    private var serverNonce: Data?
    private var clientNonce: Data?
    private var continuation: CheckedContinuation<RoverCredentials, Error>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        discovered = []
        isScanningRequested = true
        guard bluetoothReady else { return }
        central.scanForPeripherals(withServices: [Self.serviceUUID], options: nil)
    }

    func stopScan() {
        isScanningRequested = false
        central.stopScan()
    }

    /// Full sequence: connect -> CHAL -> AUTH -> STATUS -> (CRED) -> disconnect.
    func pair(with peripheral: RoverPeripheral, pin: String) async throws -> RoverCredentials {
        guard let cbPeripheral = peripheralsByID[peripheral.id] else {
            throw PairingError.disconnected
        }
        self.pin = pin
        self.serverNonce = nil
        self.clientNonce = nil
        self.activePeripheral = cbPeripheral
        cbPeripheral.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            central.connect(cbPeripheral, options: nil)
        }
    }

    func cancel() {
        if let activePeripheral {
            central.cancelPeripheralConnection(activePeripheral)
        }
        finish(.failure(PairingError.disconnected))
    }

    private func finish(_ result: Result<RoverCredentials, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        if let activePeripheral {
            central.cancelPeripheralConnection(activePeripheral)
        }
        self.activePeripheral = nil
        chalChar = nil
        authChar = nil
        statusChar = nil
        credChar = nil
        continuation.resume(with: result)
    }

    private func handleStatus(_ data: Data, peripheral: CBPeripheral) {
        let bytes = [UInt8](data)
        guard bytes.count >= 2, let code = PairingStatusCode(rawValue: bytes[0]) else {
            finish(.failure(PairingError.characteristicsMissing))
            return
        }
        let triesLeft = Int(bytes[1])
        switch code {
        case .waiting:
            break
        case .ok:
            guard let credChar else {
                finish(.failure(PairingError.characteristicsMissing))
                return
            }
            peripheral.readValue(for: credChar)
        case .badPin:
            finish(.failure(PairingError.wrongPin(triesLeft: triesLeft)))
        case .locked:
            finish(.failure(PairingError.lockedOut))
        }
    }

    private func handleCredentials(_ data: Data) {
        guard let serverNonce, let clientNonce else {
            finish(.failure(PairingError.malformedCredentials))
            return
        }
        do {
            let credentials = try PairingCrypto.decryptCredentials(
                pin: pin, serverNonce: serverNonce, clientNonce: clientNonce, blob: data
            )
            finish(.success(credentials))
        } catch {
            finish(.failure(PairingError.malformedCredentials))
        }
    }
}

extension PairingManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothReady = central.state == .poweredOn
        if bluetoothReady {
            if isScanningRequested {
                central.scanForPeripherals(withServices: [Self.serviceUUID], options: nil)
            }
        } else {
            finish(.failure(PairingError.bluetoothUnavailable))
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        peripheralsByID[peripheral.identifier] = peripheral
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Rover"
        let entry = RoverPeripheral(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let index = discovered.firstIndex(where: { $0.id == entry.id }) {
            discovered[index] = entry
        } else {
            discovered.append(entry)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish(.failure(PairingError.disconnected))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        finish(.failure(PairingError.disconnected))
    }
}

extension PairingManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            finish(.failure(PairingError.serviceNotFound))
            return
        }
        peripheral.discoverCharacteristics(
            [Self.chalUUID, Self.authUUID, Self.statusUUID, Self.credUUID], for: service
        )
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            finish(.failure(PairingError.characteristicsMissing))
            return
        }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case Self.chalUUID: chalChar = characteristic
            case Self.authUUID: authChar = characteristic
            case Self.statusUUID: statusChar = characteristic
            case Self.credUUID: credChar = characteristic
            default: break
            }
        }
        guard let chalChar, authChar != nil, statusChar != nil, credChar != nil else {
            finish(.failure(PairingError.characteristicsMissing))
            return
        }
        peripheral.readValue(for: chalChar)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else {
            finish(.failure(PairingError.disconnected))
            return
        }
        switch characteristic.uuid {
        case Self.chalUUID:
            serverNonce = data
            let (nonce, payload) = PairingCrypto.makeAuthPayload(pin: pin, serverNonce: data)
            clientNonce = nonce
            guard let authChar else {
                finish(.failure(PairingError.characteristicsMissing))
                return
            }
            peripheral.writeValue(payload, for: authChar, type: .withResponse)
        case Self.statusUUID:
            handleStatus(data, peripheral: peripheral)
        case Self.credUUID:
            handleCredentials(data)
        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.authUUID else { return }
        guard error == nil else {
            finish(.failure(PairingError.disconnected))
            return
        }
        // Give the rover's synchronous GATT write handler a little headroom,
        // matching the reference client's post-write delay before reading STATUS.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, let statusChar = self.statusChar else { return }
            peripheral.readValue(for: statusChar)
        }
    }
}

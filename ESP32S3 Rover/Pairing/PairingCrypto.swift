//
//  PairingCrypto.swift
//  ESP32S3 Rover
//

import CryptoKit
import Foundation

/// Pure cryptographic primitives for the rover's BLE pairing handshake.
/// Mirrors the firmware's `src/pairing.cpp` byte-for-byte: see that file and
/// `tools/rover_tool.py` in the esp32s3-rover firmware repo for the reference
/// implementation this must stay compatible with.
nonisolated enum PairingCrypto {
    enum CryptoError: Error {
        case malformedBlob
        case decryptionFailed
    }

    /// HMAC-SHA256(key = ASCII PIN digits, label || Ns || Nc).
    /// Used both for the AUTH proof ("auth" label) and to derive the
    /// AES-256-GCM key that decrypts the credentials blob ("enc" label).
    static func hmac(pin: String, label: String, serverNonce: Data, clientNonce: Data) -> Data {
        let key = SymmetricKey(data: Data(pin.utf8))
        var mac = HMAC<SHA256>(key: key)
        mac.update(data: Data(label.utf8))
        mac.update(data: serverNonce)
        mac.update(data: clientNonce)
        return Data(mac.finalize())
    }

    /// Generates a fresh 16-byte client nonce and the 48-byte AUTH payload
    /// (Nc || HMAC-SHA256 proof) to write to the AUTH characteristic.
    static func makeAuthPayload(pin: String, serverNonce: Data) -> (clientNonce: Data, payload: Data) {
        var clientNonce = Data(count: 16)
        clientNonce.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        let proof = hmac(pin: pin, label: "auth", serverNonce: serverNonce, clientNonce: clientNonce)
        return (clientNonce, clientNonce + proof)
    }

    /// Decrypts the CRED characteristic's value: iv[12] || ciphertext || tag[16],
    /// AES-256-GCM with AAD "rover1", key = HMAC-SHA256(PIN, "enc"||Ns||Nc).
    static func decryptCredentials(
        pin: String,
        serverNonce: Data,
        clientNonce: Data,
        blob: Data
    ) throws -> RoverCredentials {
        guard blob.count > 12 + 16 else { throw CryptoError.malformedBlob }
        let iv = blob.prefix(12)
        let tag = blob.suffix(16)
        let ciphertext = blob.dropFirst(12).dropLast(16)

        let keyData = hmac(pin: pin, label: "enc", serverNonce: serverNonce, clientNonce: clientNonce)
        let key = SymmetricKey(data: keyData)

        do {
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: Data(ciphertext), tag: Data(tag))
            let plaintext = try AES.GCM.open(sealedBox, using: key, authenticating: Data("rover1".utf8))
            return try JSONDecoder().decode(RoverCredentials.self, from: plaintext)
        } catch is DecodingError {
            throw CryptoError.malformedBlob
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}

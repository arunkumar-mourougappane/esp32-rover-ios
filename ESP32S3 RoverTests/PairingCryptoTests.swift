//
//  PairingCryptoTests.swift
//  ESP32S3 RoverTests
//

import CryptoKit
import Foundation
import Testing
@testable import ESP32S3_Rover

private func hexData(_ hex: String) -> Data {
    var data = Data()
    var remainder = Substring(hex)
    while !remainder.isEmpty {
        let next = remainder.index(remainder.startIndex, offsetBy: 2)
        data.append(UInt8(remainder[..<next], radix: 16)!)
        remainder = remainder[next...]
    }
    return data
}

struct PairingCryptoTests {
    // Test vectors independently recomputed with Python's stdlib hmac/hashlib
    // (algorithmically identical to both the firmware's mbedtls and
    // CryptoKit's HMAC<SHA256>), matching src/pairing.cpp's derivation.
    let pin = "123456"
    let serverNonce = hexData("000102030405060708090a0b0c0d0e0f")
    let clientNonce = hexData("101112131415161718191a1b1c1d1e1f")
    let expectedAuthProof = hexData("4de751ddd5b29c3131b5e06675a2ecdccb29a95219ff7a10fee067dbef58a5ce")
    let expectedEncKey = hexData("e5ecaf6c1a181471ffc217933300e60a204668ecdd8b8f4bfd352fea3fb4c645")

    @Test func authProofMatchesKnownVector() {
        let proof = PairingCrypto.hmac(pin: pin, label: "auth", serverNonce: serverNonce, clientNonce: clientNonce)
        #expect(proof == expectedAuthProof)
    }

    @Test func encKeyMatchesKnownVector() {
        let key = PairingCrypto.hmac(pin: pin, label: "enc", serverNonce: serverNonce, clientNonce: clientNonce)
        #expect(key == expectedEncKey)
    }

    @Test func authPayloadIsClientNonceFollowedByProof() {
        let (nonce, payload) = PairingCrypto.makeAuthPayload(pin: pin, serverNonce: serverNonce)
        #expect(payload.count == 48)
        #expect(payload.prefix(16) == nonce)
        let proof = PairingCrypto.hmac(pin: pin, label: "auth", serverNonce: serverNonce, clientNonce: nonce)
        #expect(payload.suffix(32) == proof)
    }

    @Test func decryptCredentialsRoundTrips() throws {
        let credentials = RoverCredentials(ssid: "Rover-ABCD", pass: "abcdefghijkl", ip: "192.168.4.1", http: 80, ws: 81)
        let plaintext = try JSONEncoder().encode(credentials)
        let key = SymmetricKey(data: expectedEncKey)
        let sealedBox = try AES.GCM.seal(plaintext, using: key, authenticating: Data("rover1".utf8))
        let blob = try #require(sealedBox.combined)

        let decoded = try PairingCrypto.decryptCredentials(
            pin: pin, serverNonce: serverNonce, clientNonce: clientNonce, blob: blob
        )
        #expect(decoded == credentials)
    }

    @Test func decryptCredentialsRejectsTamperedBlob() {
        let credentials = RoverCredentials(ssid: "Rover-ABCD", pass: "abcdefghijkl", ip: "192.168.4.1", http: 80, ws: 81)
        let plaintext = try! JSONEncoder().encode(credentials)
        let key = SymmetricKey(data: expectedEncKey)
        let sealedBox = try! AES.GCM.seal(plaintext, using: key, authenticating: Data("rover1".utf8))
        var blob = sealedBox.combined!
        blob[blob.count - 1] ^= 0xFF // corrupt the tag

        #expect(throws: (any Error).self) {
            try PairingCrypto.decryptCredentials(
                pin: pin, serverNonce: serverNonce, clientNonce: clientNonce, blob: blob
            )
        }
    }
}

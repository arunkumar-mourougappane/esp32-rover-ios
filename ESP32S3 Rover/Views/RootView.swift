//
//  RootView.swift
//  ESP32S3 Rover
//

import SwiftUI

struct RootView: View {
    @State private var store = RoverSessionStore()
    @Environment(\.colorScheme) private var colorScheme

    /// The driving screen follows system appearance: Cyber Teal in dark
    /// mode, Daylight in light mode (the latter chosen for outdoor sun
    /// glare readability). See `RoverPalette`.
    private var palette: RoverPalette {
        colorScheme == .dark ? .cyberTeal : .daylight
    }

    var body: some View {
        Group {
            switch store.phase {
            case .scanning:
                ScanView(store: store)
            case .pairing(let peripheral):
                ConnectingView(message: "Pairing with \(peripheral.name)…")
            case .joiningWiFi(let credentials):
                WiFiJoinView(store: store, credentials: credentials)
            case .connectingLink:
                ConnectingView(message: "Connecting to the rover…")
            case .driving:
                ControlView(store: store)
            case .error(let message):
                ErrorView(
                    message: message,
                    onReconnect: store.lastCredentials != nil ? { Task { await store.reconnect() } } : nil,
                    onStartOver: store.retry
                )
            }
        }
        .animation(.default, value: store.phase)
        .environment(\.roverPalette, palette)
        .tint(palette.accent)
    }
}

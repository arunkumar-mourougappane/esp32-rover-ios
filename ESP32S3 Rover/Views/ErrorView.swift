//
//  ErrorView.swift
//  ESP32S3 Rover
//

import SwiftUI

struct ErrorView: View {
    let message: String
    /// Non-nil when a dropped connection can skip straight back to the
    /// WebSocket link instead of a full BLE re-pair. `nil` hides the button.
    let onReconnect: (() -> Void)?
    let onStartOver: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Connection Failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(RoverTheme.bad)
        } description: {
            Text(message)
        } actions: {
            if let onReconnect {
                Button("Reconnect", action: onReconnect)
                    .buttonStyle(.borderedProminent)
                    .tint(RoverTheme.accent)
                Button("Start Over", action: onStartOver)
                    .buttonStyle(.bordered)
                    .tint(RoverTheme.dim)
            } else {
                Button("Try Again", action: onStartOver)
                    .buttonStyle(.borderedProminent)
                    .tint(RoverTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoverTheme.background)
    }
}

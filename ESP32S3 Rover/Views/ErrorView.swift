//
//  ErrorView.swift
//  ESP32S3 Rover
//

import SwiftUI

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Connection Failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(RoverTheme.bad)
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(RoverTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoverTheme.background)
    }
}

//
//  ConnectingView.swift
//  ESP32S3 Rover
//

import SwiftUI

struct ConnectingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(RoverTheme.accent)
            Text(message)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoverTheme.background)
    }
}

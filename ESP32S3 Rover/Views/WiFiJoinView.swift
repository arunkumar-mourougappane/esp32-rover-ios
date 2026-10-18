//
//  WiFiJoinView.swift
//  ESP32S3 Rover
//

import SwiftUI
import UIKit

/// Asks the user to manually join the rover's Wi-Fi network from Settings.
/// Auto-join via `NEHotspotConfiguration` needs the paid Apple Developer
/// Program's Hotspot Configuration capability, unavailable to personal/free
/// teams, so this is the fallback that works for everyone.
struct WiFiJoinView: View {
    let store: RoverSessionStore
    let credentials: RoverCredentials

    @Environment(\.openURL) private var openURL
    @State private var isVerifying = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi")
                .font(.system(size: 48))
                .foregroundStyle(RoverTheme.accent)

            Text("Join the Rover's Wi-Fi")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                LabeledContent("Network", value: credentials.ssid)
                Divider().overlay(RoverTheme.dim.opacity(0.3))
                LabeledContent("Password", value: credentials.pass)
            }
            .font(.body.monospaced())
            .foregroundStyle(.primary)
            .padding()
            .background(RoverTheme.surface, in: RoundedRectangle(cornerRadius: 12))

            Text("Open Settings, join this network, then come back and tap Continue.")
                .font(.footnote)
                .foregroundStyle(RoverTheme.dim)
                .multilineTextAlignment(.center)

            if let error = store.wifiVerificationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(RoverTheme.bad)
                    .multilineTextAlignment(.center)
            }

            Button("Open Wi-Fi Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(RoverTheme.accent)

            Button {
                isVerifying = true
                Task {
                    await store.confirmWiFiJoined()
                    isVerifying = false
                }
            } label: {
                if isVerifying {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(RoverTheme.accent)
            .disabled(isVerifying)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoverTheme.background)
    }
}

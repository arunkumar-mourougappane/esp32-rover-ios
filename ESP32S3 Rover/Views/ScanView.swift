//
//  ScanView.swift
//  ESP32S3 Rover
//

import SwiftUI

struct ScanView: View {
    let store: RoverSessionStore
    @State private var selectedPeripheral: PairingManager.RoverPeripheral?

    var body: some View {
        NavigationStack {
            List {
                if !store.pairingManager.bluetoothReady {
                    ContentUnavailableView(
                        "Bluetooth Unavailable",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Turn on Bluetooth to find your rover.")
                    )
                    .listRowBackground(Color.clear)
                } else if store.pairingManager.discovered.isEmpty {
                    ContentUnavailableView(
                        "Looking for a Rover…",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Press BOOT on the rover to open its pairing window.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.pairingManager.discovered) { peripheral in
                        Button {
                            selectedPeripheral = peripheral
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.title3)
                                    .foregroundStyle(signalColor(for: peripheral.rssi))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(peripheral.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("RSSI \(peripheral.rssi) dBm")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(RoverTheme.dim)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(RoverTheme.dim)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(RoverTheme.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RoverTheme.background)
            .navigationTitle("Find Your Rover")
            .onAppear { store.startScan() }
            .sheet(item: $selectedPeripheral) { peripheral in
                PinEntryView(peripheral: peripheral) { pin in
                    selectedPeripheral = nil
                    Task { await store.pair(with: peripheral, pin: pin) }
                }
            }
        }
    }

    private func signalColor(for rssi: Int) -> Color {
        if rssi >= -60 { return RoverTheme.ok }
        if rssi >= -80 { return RoverTheme.warn }
        return RoverTheme.bad
    }
}

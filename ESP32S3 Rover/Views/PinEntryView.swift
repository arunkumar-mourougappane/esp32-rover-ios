//
//  PinEntryView.swift
//  ESP32S3 Rover
//

import SwiftUI

struct PinEntryView: View {
    let peripheral: PairingManager.RoverPeripheral
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @FocusState private var fieldFocused: Bool

    private static let digitCount = 6

    private var isValid: Bool {
        pin.count == Self.digitCount && pin.allSatisfy(\.isNumber)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: "number.square.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(RoverTheme.accent)
                    .padding(.top, 12)

                Text("Enter the 6-digit PIN shown on \(peripheral.name)'s screen.")
                    .font(.subheadline)
                    .foregroundStyle(RoverTheme.dim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ZStack {
                    HStack(spacing: 10) {
                        ForEach(0..<Self.digitCount, id: \.self) { index in
                            digitBox(at: index)
                        }
                    }
                    TextField("", text: $pin)
                        .keyboardType(.numberPad)
                        .focused($fieldFocused)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .onChange(of: pin) { _, newValue in
                            pin = String(newValue.filter(\.isNumber).prefix(Self.digitCount))
                        }
                }
                .onTapGesture { fieldFocused = true }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoverTheme.background)
            .navigationTitle("Pair with Rover")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pair") { onSubmit(pin) }
                        .disabled(!isValid)
                }
            }
            .onAppear { fieldFocused = true }
        }
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(pin)
        let digit = index < characters.count ? String(characters[index]) : ""
        let isNext = index == characters.count

        return Text(digit)
            .font(.title2.monospacedDigit().bold())
            .foregroundStyle(.primary)
            .frame(width: 40, height: 52)
            .background(RoverTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isNext ? RoverTheme.accent : .clear, lineWidth: 2)
            )
    }
}

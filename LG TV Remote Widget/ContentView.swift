//
//  ContentView.swift
//  LG TV Remote Widget.
//
//  Created by Bardia Barabadi on 2025-10-23.
//

import SwiftUI
import Combine
import LGTVControl

struct ContentView: View {
    @StateObject private var viewModel = ConnectionViewModel()
    @FocusState private var focusedField: Field?

    enum Field {
        case ip, mac, pairing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("TV Details") {
                    TextField("IP Address", text: $viewModel.ipAddress)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .ip)
                        .submitLabel(.next)
                    TextField("MAC Address", text: $viewModel.macAddress)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .mac)
                        .submitLabel(.done)
                }

                Section("Connection") {
                    HStack(spacing: 12) {
                        statusIndicator
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.statusText)
                                .font(.headline)
                            if let detail = viewModel.statusDetail {
                                Text(detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if viewModel.isConnecting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Button(action: connectTapped) {
                        Label("Connect", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .disabled(!viewModel.canAttemptConnection || viewModel.isConnecting)

                    Button(role: .destructive, action: viewModel.disconnect) {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                    .disabled(!viewModel.isConnected)
                }

                if let message = viewModel.errorMessage {
                    Section("Error") {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("LG TV Setup")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $viewModel.showPairingSheet) {
                PairingCodeSheet(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .onAppear { viewModel.refreshStatus() }
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(viewModel.statusColor)
            .frame(width: 14, height: 14)
    }

    private func connectTapped() {
        focusedField = nil
        viewModel.connect()
    }
}

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published var ipAddress: String
    @Published var macAddress: String
    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published var isConnecting = false
    @Published var showPairingSheet = false
    @Published var pairingCodeInput = ""
    @Published var pendingPairingCode: String?
    @Published var errorMessage: String?

    private let manager = LGTVControlManager.shared

    init() {
        if let stored = manager.loadCredentials() {
            self.ipAddress = stored.ipAddress
            self.macAddress = stored.macAddress
        } else {
            self.ipAddress = "10.0.0.14"
            self.macAddress = "34:E6:E6:F9:05:50"
        }
        refreshStatus()
    }

    var canAttemptConnection: Bool {
        !ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        macAddress.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12
    }

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    var statusText: String {
        switch status {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        case .pairingRequired:
            return "Pairing Required"
        case .error:
            return "Error"
        }
    }

    var statusDetail: String? {
        switch status {
        case .pairingRequired(let code):
            if let code {
                return "Enter the code shown on your TV: \(code)"
            }
            return "Look at your TV for the pairing PIN."
        case .error(let message):
            return message
        default:
            return nil
        }
    }

    var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .pairingRequired:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }

    func refreshStatus() {
        status = manager.getConnectionStatus()
    }

    func connect() {
        errorMessage = nil
        isConnecting = true
        let ip = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let mac = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let pairingCode = try await manager.connect(ip: ip, mac: mac)
                await MainActor.run {
                    isConnecting = false
                    status = manager.getConnectionStatus()
                    pendingPairingCode = pairingCode
                    
                    // Only show pairing sheet if we have a code (PIN mode)
                    // If no code, TV is using PROMPT mode (just Allow/Deny on TV)
                    if statusRequiresPairing(status) {
                        if let code = pairingCode {
                            // PIN mode - show code entry sheet
                            pairingCodeInput = code
                            showPairingSheet = true
                        } else {
                            // PROMPT mode - just wait for user to accept on TV
                            // Status will update automatically when accepted
                            print("[ContentView] Waiting for user to accept pairing on TV...")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    status = manager.getConnectionStatus()
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func submitPairingCode() {
        let code = pairingCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "Pairing code cannot be empty."
            return
        }
        isConnecting = true
        showPairingSheet = false
        Task {
            do {
                try await manager.submitPairingCode(code)
                await MainActor.run {
                    isConnecting = false
                    status = manager.getConnectionStatus()
                    if isConnected { errorMessage = nil }
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    status = manager.getConnectionStatus()
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func disconnect() {
        manager.disconnect()
        status = manager.getConnectionStatus()
    }

    private func statusRequiresPairing(_ status: ConnectionStatus) -> Bool {
        if case .pairingRequired = status { return true }
        return false
    }
}

private struct PairingCodeSheet: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @FocusState private var pairingFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter the PIN displayed on your TV")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                TextField("Pairing Code", text: $viewModel.pairingCodeInput)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .focused($pairingFieldFocused)
                Button(action: viewModel.submitPairingCode) {
                    Label("Submit", systemImage: "checkmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showPairingSheet = false
                    }
                }
            }
            .onAppear { pairingFieldFocused = true }
        }
    }
}

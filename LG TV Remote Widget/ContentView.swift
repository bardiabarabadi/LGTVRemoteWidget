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
                    
                    Button(action: { viewModel.powerOn() }) {
                        Label("Wake TV (WOL)", systemImage: "power.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.isConnecting)
                }

                if let message = viewModel.errorMessage {
                    Section("Error") {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
                
                // Command Testing Section
                if viewModel.isConnected {
                    Section("Test Commands") {
                        VStack(spacing: 16) {
                            // Volume Controls
                            HStack(spacing: 12) {
                                Button(action: { viewModel.sendCommand("ssap://audio/volumeUp") }) {
                                    Label("Vol +", systemImage: "speaker.wave.3")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.sendCommand("ssap://audio/volumeDown") }) {
                                    Label("Vol −", systemImage: "speaker.wave.1")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.sendCommand("ssap://audio/setMute", ["mute": true]) }) {
                                    Label("Mute", systemImage: "speaker.slash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // HDMI Inputs
                            HStack(spacing: 12) {
                                Button(action: { viewModel.sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_1"]) }) {
                                    Text("HDMI 1")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_2"]) }) {
                                    Text("HDMI 2")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_3"]) }) {
                                    Text("HDMI 3")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // App Launchers
                            HStack(spacing: 12) {
                                Button(action: { viewModel.sendCommand("ssap://system.launcher/launch", ["id": "cdp-30"]) }) {
                                    Label("Plex", systemImage: "play.tv")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                
                                Button(action: { viewModel.sendCommand("ssap://system.launcher/launch", ["id": "youtube.leanback.v4"]) }) {
                                    Label("YouTube", systemImage: "play.rectangle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            
                            // Navigation Controls
                            VStack(spacing: 8) {
                                // Home and Back buttons (using system.launcher)
                                HStack(spacing: 12) {
                                    Button(action: { viewModel.sendButton(.home) }) {
                                        Label("Home", systemImage: "house")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: { viewModel.sendButton(.back) }) {
                                        Label("Back", systemImage: "arrow.uturn.backward")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                // Arrow D-Pad (using pointer input socket)
                                Button(action: { viewModel.sendButton(.up) }) {
                                    Image(systemName: "chevron.up")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.bordered)
                                
                                // Left, OK, Right
                                HStack(spacing: 12) {
                                    Button(action: { viewModel.sendButton(.left) }) {
                                        Image(systemName: "chevron.left")
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: { viewModel.sendButton(.enter) }) {
                                        Text("OK")
                                            .font(.headline)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button(action: { viewModel.sendButton(.right) }) {
                                        Image(systemName: "chevron.right")
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                // Down arrow
                                Button(action: { viewModel.sendButton(.down) }) {
                                    Image(systemName: "chevron.down")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Power Off only (Power On is in Connection section)
                            Button(role: .destructive, action: { viewModel.sendCommand("ssap://system/turnOff") }) {
                                Label("Power Off", systemImage: "power.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                        
                        if let commandResult = viewModel.commandResult {
                            Text(commandResult)
                                .font(.caption)
                                .foregroundStyle(viewModel.commandSuccess ? .green : .red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
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
    @Published var commandResult: String?
    @Published var commandSuccess: Bool = true

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
    
    func sendCommand(_ uri: String, _ parameters: [String: Any]? = nil) {
        commandResult = nil
        Task {
            do {
                try await manager.sendCommand(uri, parameters: parameters)
                await MainActor.run {
                    commandSuccess = true
                    commandResult = "✅ Command sent: \(uri.components(separatedBy: "/").last ?? uri)"
                }
                // Clear result after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    commandResult = nil
                }
            } catch {
                await MainActor.run {
                    commandSuccess = false
                    commandResult = "❌ Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func sendButton(_ button: PointerInputClient.Button) {
        commandResult = nil
        Task {
            do {
                try await manager.sendButton(button)
                await MainActor.run {
                    commandSuccess = true
                    commandResult = "✅ Button: \(button.rawValue)"
                }
                // Clear result after 2 seconds (faster for navigation)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    commandResult = nil
                }
            } catch {
                await MainActor.run {
                    commandSuccess = false
                    commandResult = "❌ Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func powerOn() {
        commandResult = nil
        let mac = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let ip = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await manager.wakeTV(mac: mac, ip: ip)
                await MainActor.run {
                    commandSuccess = true
                    commandResult = "✅ Wake-on-LAN sent to TV"
                }
                // Clear result after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    commandResult = nil
                }
            } catch {
                await MainActor.run {
                    commandSuccess = false
                    commandResult = "❌ WOL Error: \(error.localizedDescription)"
                }
            }
        }
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

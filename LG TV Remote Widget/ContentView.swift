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
                // Remote Control Section - Always visible (moved to top)
                Section("Remote Control") {
                    VStack(spacing: 16) {
                        // Power Toggle (icon only, circular)
                        Button(action: { viewModel.powerToggle() }) {
                            Image(systemName: "power")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color(red: 1.0, green: 0.27, blue: 0.23))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canSendCommands)
                        .frame(maxWidth: .infinity)
                        
                        // Apps Row
                        HStack(spacing: 12) {
                            Button(action: { viewModel.sendCommand("ssap://system.launcher/launch", ["id": "cdp-30"]) }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "film.fill")
                                        .font(.system(size: 24))
                                    Text("Plex")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color(red: 0.9, green: 0.5, blue: 0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSendCommands)
                            
                            Button(action: { viewModel.sendCommand("ssap://system.launcher/launch", ["id": "youtube.leanback.v4"]) }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 24))
                                    Text("YouTube")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color(red: 1.0, green: 0.18, blue: 0.18))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSendCommands)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: { viewModel.sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_1"]) }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 24))
                                    Text("Gaming")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color(red: 0.3, green: 0.78, blue: 0.4))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSendCommands)
                            
                            Button(action: { viewModel.sendCommand("ssap://tv/switchInput", ["inputId": "HDMI_2"]) }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "rectangle.connected.to.line.below")
                                        .font(.system(size: 24))
                                    Text("HDMI 2")
                                        .font(.caption)
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSendCommands)
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Navigation Cluster
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: { viewModel.sendButton(.home) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "house.fill")
                                            .font(.system(size: 18))
                                        Text("Home")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.canSendCommands)
                                
                                Button(action: { viewModel.sendButton(.back) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.uturn.left")
                                            .font(.system(size: 18))
                                        Text("Back")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.canSendCommands)
                            }
                            
                            // D-Pad
                            VStack(spacing: 10) {
                                Button(action: { viewModel.sendButton(.up) }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 60, height: 60)
                                        .background(Color(.systemGray6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.canSendCommands)
                                
                                HStack(spacing: 16) {
                                    Button(action: { viewModel.sendButton(.left) }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 60, height: 60)
                                            .background(Color(.systemGray6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                    
                                    Button(action: { viewModel.sendButton(.enter) }) {
                                        Text("OK")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(width: 70, height: 70)
                                            .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                    
                                    Button(action: { viewModel.sendButton(.right) }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 60, height: 60)
                                            .background(Color(.systemGray6))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                }
                                
                                Button(action: { viewModel.sendButton(.down) }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 60, height: 60)
                                        .background(Color(.systemGray6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!viewModel.canSendCommands)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Volume & Playback Controls
                        VStack(spacing: 16) {
                            // Volume Section
                            VStack(spacing: 10) {
                                Text("Volume")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 10) {
                                    Button(action: { viewModel.sendCommand("ssap://audio/volumeDown") }) {
                                        Image(systemName: "minus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                    
                                    Button(action: { viewModel.sendCommand("ssap://audio/volumeMute") }) {
                                        Image(systemName: "speaker.slash.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, minHeight: 50)
                                            .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                                            .cornerRadius(25)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                    
                                    Button(action: { viewModel.sendCommand("ssap://audio/volumeUp") }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                }
                            }
                            
                            // Playback Section
                            VStack(spacing: 10) {
                                Text("Playback")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 12) {
                                    Button(action: { viewModel.sendCommand("ssap://media.controls/play") }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 18))
                                            Text("Play")
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                        .background(Color(red: 0.55, green: 0.55, blue: 0.58))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                    
                                    Button(action: { viewModel.sendCommand("ssap://media.controls/pause") }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "pause.fill")
                                                .font(.system(size: 18))
                                            Text("Pause")
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                        .background(Color(red: 0.55, green: 0.55, blue: 0.58))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.canSendCommands)
                                }
                            }
                        }
                        
                        if let commandResult = viewModel.commandResult {
                            Text(commandResult)
                                .font(.caption)
                                .foregroundStyle(viewModel.commandSuccess ? .green : .red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
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
                    
                    Button(role: .destructive, action: { viewModel.clearCredentials() }) {
                        Label("Clear Credentials (Force Re-Pair)", systemImage: "trash.circle")
                    }
                    .disabled(viewModel.isConnecting)
                }

                if let message = viewModel.errorMessage {
                    Section("Error") {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("LG TV Remote")
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
    
    var canSendCommands: Bool {
        // Allow sending commands even when disconnected for Wake-on-LAN
        return !isConnecting
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
    
    func powerToggle() {
        commandResult = nil
        let mac = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let ip = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                // Try Wake-on-LAN first
                try await manager.wakeTV(mac: mac, ip: ip)
                
                // Small delay
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // Then try power off (will only work if connected)
                try await manager.sendCommand("ssap://system/turnOff")
                
                await MainActor.run {
                    commandSuccess = true
                    commandResult = "✅ Power toggle sent"
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
    
    func clearCredentials() {
        disconnect()
        manager.clearCredentials()
        commandResult = nil
        errorMessage = nil
        commandSuccess = true
        commandResult = "✅ Credentials cleared. Next connection will require pairing."
        
        // Clear result after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                commandResult = nil
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

#Preview {
    ContentView()
}

import Foundation

public final class LGTVControlManager {
    public static let shared = LGTVControlManager()

    public enum ControlError: Error, LocalizedError {
        case notConnected
        case missingCredentials
        case invalidPairingCode
        case pairingFailed

        public var errorDescription: String? {
            switch self {
            case .notConnected: return "Not connected to the TV"
            case .missingCredentials: return "Missing credentials. Connect to the TV first."
            case .invalidPairingCode: return "The pairing code was rejected by the TV"
            case .pairingFailed: return "The TV reported a pairing failure"
            }
        }
    }

    // MARK: - Constants
    public struct Constants {
        public static let keychainService = "com.DaraConsultingInc.LGTVRemoteWidget.credentials"
        public static let keychainAccount = "default"
        public static let lastStatusKey = "lastConnectionStatus"
    }

    private let webSocket = SSAPWebSocketClient()
    private let keychain = KeychainManager()
    private let wol = WakeOnLAN()

    private var currentCredentials: TVCredentials?
    private var status: ConnectionStatus = .disconnected {
        didSet {
            AppGroupManager.shared.setString(statusText, forKey: Constants.lastStatusKey)
        }
    }

    private var statusText: String {
        switch status {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .pairingRequired: return "pairing"
        case .error(let msg): return "error: \(msg)"
        }
    }

    private init() {}

    // MARK: - Public API

    @discardableResult
    public func connect(ip: String, mac: String) async throws -> String? {
        print("[LGTVControlManager] 🔵 Connect requested - IP: \(ip), MAC: \(mac)")
        status = .connecting

        let normalizedMac = mac.uppercased()
        var credentials = TVCredentials(ipAddress: ip, macAddress: normalizedMac)
        if let stored: TVCredentials = try? keychain.load(TVCredentials.self, service: Constants.keychainService, account: Constants.keychainAccount),
           stored.ipAddress == ip,
           stored.macAddress.uppercased() == normalizedMac {
            credentials.clientKey = stored.clientKey
            print("[LGTVControlManager] 🔑 Found stored credentials with client key")
        } else {
            print("[LGTVControlManager] 📝 No stored credentials found, will pair fresh")
        }
        currentCredentials = credentials

        do {
            // Try Bonjour discovery first
            print("[LGTVControlManager] 🔍 Attempting Bonjour discovery...")
            let discovery = LGTVDiscovery()
            let devices = await discovery.discover(timeout: 3.0)
            if !devices.isEmpty {
                for device in devices {
                    print("[LGTVControlManager] 📺 Discovered: \(device.name) at \(device.ip):\(device.port)")
                }
            } else {
                print("[LGTVControlManager] ⚠️ No devices found via Bonjour discovery")
            }
            
            // Run diagnostics
            print("[LGTVControlManager] 🔍 Running network diagnostics...")
            let tcpTest = await NetworkDiagnostics.testTCPConnection(host: ip, port: 3000)
            print("[LGTVControlManager] TCP Test (3000): \(tcpTest.success ? "✅" : "❌") \(tcpTest.message)")
            
            // Also test port 3001 in case TV uses secure WebSocket
            let tcpTest3001 = await NetworkDiagnostics.testTCPConnection(host: ip, port: 3001)
            print("[LGTVControlManager] TCP Test (3001): \(tcpTest3001.success ? "✅" : "❌") \(tcpTest3001.message)")
            
            // Test raw WebSocket handshake to see what the TV responds
            let rawTest = await RawWebSocketTest.testRawWebSocketHandshake(host: ip, port: 3000)
            print("[LGTVControlManager] Raw WebSocket Test (port 3000): \(rawTest.success ? "✅" : "❌")")
            print("[LGTVControlManager] TV Response: \(rawTest.response)")
            
            // If port 3000 fails, try 3001
            if !rawTest.success && tcpTest3001.success {
                print("[LGTVControlManager] 🔄 Trying port 3001...")
                let rawTest3001 = await RawWebSocketTest.testRawWebSocketHandshake(host: ip, port: 3001)
                print("[LGTVControlManager] Raw WebSocket Test (port 3001): \(rawTest3001.success ? "✅" : "❌")")
                print("[LGTVControlManager] TV Response: \(rawTest3001.response)")
                
                // Also try HTTPS on port 3001
                print("[LGTVControlManager] 🔄 Trying HTTPS on port 3001...")
                if let url = URL(string: "https://\(ip):3001/") {
                    do {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 5
                        let (data, response) = try await URLSession.shared.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse {
                            let body = String(data: data, encoding: .utf8) ?? "<binary>"
                            print("[LGTVControlManager] HTTPS Response (3001): Status \(httpResponse.statusCode)")
                            print("[LGTVControlManager] Body: \(body)")
                        }
                    } catch {
                        print("[LGTVControlManager] HTTPS Test (3001): ❌ \(error.localizedDescription)")
                    }
                }
            }
            
            if !tcpTest.success && !tcpTest3001.success {
                throw ControlError.notConnected
            }
            
            print("[LGTVControlManager] 📋 Analysis: Port 3000 resets (disabled), Port 3001 available")
            print("[LGTVControlManager] 💡 webOS 23 requires secure WebSocket (wss://) on port 3001")
            
            print("[LGTVControlManager] 🔌 Initiating SECURE WebSocket connection (wss://\(ip):3001/)...")
            try await webSocket.connect(to: ip, useSecure: true)
            print("[LGTVControlManager] ✅ WebSocket connected, starting registration...")
            let result = try await webSocket.register(manifest: manifest, clientKey: credentials.clientKey)
            switch result {
            case .success(let clientKey):
                print("[LGTVControlManager] ✅ Registration successful!")
                credentials.clientKey = clientKey
                saveCredentials(credentials)
                currentCredentials = credentials
                status = .connected
                return nil
            case .pairingRequired(let code):
                print("[LGTVControlManager] 🔐 Pairing required - code: \(code ?? "none")")
                status = .pairingRequired(code: code)
                return code
            }
        } catch {
            print("[LGTVControlManager] ❌ Connection/registration failed: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
            webSocket.disconnect()
            throw error
        }
    }

    public func submitPairingCode(_ code: String) async throws {
        guard var credentials = currentCredentials else {
            throw ControlError.missingCredentials
        }

        status = .connecting
        do {
            let result = try await webSocket.submitPairingCode(code, manifest: manifest, clientKey: credentials.clientKey)
            switch result {
            case .success(let clientKey):
                credentials.clientKey = clientKey
                saveCredentials(credentials)
                currentCredentials = credentials
                status = .connected
            case .pairingRequired:
                status = .pairingRequired(code: nil)
                throw ControlError.invalidPairingCode
            }
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
    }

    public func sendCommand(_ command: String, parameters: [String: Any]? = nil) async throws {
        guard case .connected = status else { throw ControlError.notConnected }
        var payload: [String: AnyCodable]? = nil
        if let parameters {
            var dict: [String: AnyCodable] = [:]
            for (k, v) in parameters { dict[k] = AnyCodable(v) }
            payload = dict
        }
        let req = SSAPRequest(type: .request, uri: command, payload: payload)
        let response = try await webSocket.sendRequest(req)
        if let response, response.type == "error" {
            let message = response.error ?? "Unknown error"
            throw SSAPWebSocketClient.ClientError.serverError(message)
        }
        if let returnValue = response?.returnValue, returnValue == false {
            let message = response?.error ?? "Command rejected"
            throw SSAPWebSocketClient.ClientError.serverError(message)
        }
    }

    public func disconnect() {
        webSocket.disconnect()
        status = .disconnected
    }

    public func wakeTV(mac: String) async throws {
        try await wol.send(macAddress: mac)
        // Give the TV a moment to wake up (callers should handle additional waits)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    public func getConnectionStatus() -> ConnectionStatus { status }

    public func saveCredentials(_ credentials: TVCredentials) {
        try? keychain.save(credentials, service: Constants.keychainService, account: Constants.keychainAccount)
        currentCredentials = credentials
    }

    public func loadCredentials() -> TVCredentials? {
        if let creds: TVCredentials = try? keychain.load(TVCredentials.self, service: Constants.keychainService, account: Constants.keychainAccount) {
            currentCredentials = creds
            return creds
        }
        return nil
    }

    // MARK: - Helpers

    private var manifest: SSAPManifest {
        SSAPManifest(
            manifestVersion: 1,
            appId: "com.DaraConsultingInc.LGTVRemoteWidget",
            appName: "LG TV Remote Widget",
            vendorName: "Dara Consulting Inc.",
            version: "1.0.0",
            permissions: [
                "LAUNCH",
                "LAUNCH_WEBAPP",
                "APP_TO_APP",
                "CONTROL_AUDIO",
                "CONTROL_DISPLAY",
                "CONTROL_INPUT_MEDIA_PLAYER",
                "CONTROL_POWER",
                "READ_INSTALLED_APPS",
                "CONTROL_INPUT_JOYSTICK"
            ],
            signatures: [
                .init(signatureVersion: 1, signature: "")
            ],
            localizedAppNames: [
                "": "LG TV Remote Widget",
                "en-US": "LG TV Remote Widget"
            ],
            localizedVendorNames: [
                "": "Dara Consulting Inc.",
                "en-US": "Dara Consulting Inc."
            ],
            categories: ["remotecontrol"],
            devices: ["mobile"]
        )
    }
}

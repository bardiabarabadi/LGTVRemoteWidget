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
    private var pointerInput: PointerInputClient?

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
            // Connect directly using secure WebSocket (webOS 23 requirement)
            print("[LGTVControlManager] � Connecting to wss://\(ip):3001/...")
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
                
                // Setup pointer input socket for navigation
                do {
                    print("[LGTVControlManager] 🎮 Starting pointer input setup...")
                    try await setupPointerInput()
                    print("[LGTVControlManager] ✅ Pointer input setup complete")
                } catch {
                    print("[LGTVControlManager] ⚠️ Failed to setup pointer input: \(error)")
                    // Don't fail connection if pointer setup fails - can retry later
                }
                
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
        pointerInput?.disconnect()
        pointerInput = nil
        status = .disconnected
    }

    public func wakeTV(mac: String, ip: String? = nil) async throws {
        print("[LGTVControlManager] 📡 Sending Wake-on-LAN to MAC: \(mac), IP: \(ip ?? "broadcast")")
        try await wol.send(macAddress: mac, ipAddress: ip)
        print("[LGTVControlManager] ✅ Wake-on-LAN packets sent")
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
    
    /// Clear stored credentials - useful for forcing re-pairing with new permissions
    public func clearCredentials() {
        print("[LGTVControlManager] 🗑️ Clearing stored credentials")
        try? keychain.delete(service: Constants.keychainService, account: Constants.keychainAccount)
        currentCredentials = nil
        print("[LGTVControlManager] ✅ Credentials cleared - next connection will require pairing")
    }
    
    // MARK: - Pointer Input (Navigation)
    
    private func setupPointerInput() async throws {
        print("[LGTVControlManager] 🎮 Setting up pointer input socket...")
        
        // Request pointer socket path
        let request = SSAPRequest(type: .request, uri: "ssap://com.webos.service.networkinput/getPointerInputSocket")
        guard let response = try await webSocket.sendRequest(request),
              let socketPath = response.payload?["socketPath"]?.value as? String else {
            print("[LGTVControlManager] ❌ Failed to get pointer socket path - trying alternative method")
            throw ControlError.notConnected
        }
        
        print("[LGTVControlManager] 📍 Got pointer socket path: \(socketPath)")
        
        // Connect to pointer socket
        let pointer = PointerInputClient()
        try await pointer.connect(socketPath: socketPath)
        self.pointerInput = pointer
        
        print("[LGTVControlManager] ✅ Pointer input ready")
    }
    
    /// Alternative method: Try sending button via different API
    private func sendButtonViaAlternativeAPI(_ button: PointerInputClient.Button) async throws {
        print("[LGTVControlManager] 🔄 Trying alternative button API...")
        
        // Try different URIs that might work
        let uris = [
            "ssap://com.webos.service.tv.keymanager/processKeyInput",
            "ssap://com.webos.service.networkinput/sendKeyEvent"
        ]
        
        for uri in uris {
            do {
                let params: [String: AnyCodable] = [
                    "key": AnyCodable(button.rawValue),
                    "keyCode": AnyCodable(button.rawValue)
                ]
                let request = SSAPRequest(type: .request, uri: uri, payload: params)
                let response = try await webSocket.sendRequest(request)
                print("[LGTVControlManager] ✅ Alternative API worked with URI: \(uri)")
                return
            } catch {
                print("[LGTVControlManager] ❌ Alternative URI failed: \(uri) - \(error)")
            }
        }
        
        throw ControlError.notConnected
    }
    
    public func sendButton(_ button: PointerInputClient.Button) async throws {
        print("[LGTVControlManager] 🎮 sendButton(\(button.rawValue)) called")
        print("[LGTVControlManager] 🔍 Current status: \(status)")
        print("[LGTVControlManager] 🔍 Pointer input exists: \(pointerInput != nil)")
        
        // Check if we have pointer input, if not try to set it up
        if pointerInput == nil {
            print("[LGTVControlManager] ⚠️ Pointer input not set up, attempting to connect...")
            do {
                try await setupPointerInput()
                print("[LGTVControlManager] ✅ Setup completed, pointer input now: \(pointerInput != nil)")
            } catch {
                print("[LGTVControlManager] ⚠️ Pointer socket setup failed, trying alternative API...")
                // If pointer socket fails, try alternative method
                try await sendButtonViaAlternativeAPI(button)
                return
            }
        }
        
        guard let pointerInput = pointerInput else {
            print("[LGTVControlManager] ❌ No pointer input available, trying alternative API...")
            try await sendButtonViaAlternativeAPI(button)
            return
        }
        
        print("[LGTVControlManager] 📤 Delegating to PointerInputClient...")
        try await pointerInput.sendButton(button)
        print("[LGTVControlManager] ✅ Button sent successfully via manager")
    }
    
    public func sendClick() async throws {
        guard let pointerInput = pointerInput else {
            throw ControlError.notConnected
        }
        
        try await pointerInput.sendClick()
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
                "CONTROL_INPUT_JOYSTICK",
                "CONTROL_INPUT_TEXT",
                "CONTROL_INPUT_MEDIA_RECORDING",
                "CONTROL_INPUT_MEDIA_PLAYBACK",
                "CONTROL_MOUSE_AND_KEYBOARD",
                "READ_CURRENT_CHANNEL",
                "READ_RUNNING_APPS",
                "READ_TV_CURRENT_TIME",
                "CONTROL_TV_SCREEN",
                "CONTROL_TV_STANBY",
                "READ_LGE_SDX",
                "READ_LGE_TV_INPUT_EVENTS",
                "READ_TV_CHANNEL_LIST",
                "WRITE_SETTINGS",
                "WRITE_NOTIFICATION_TOAST",
                "CONTROL_INPUT_POINTER"
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

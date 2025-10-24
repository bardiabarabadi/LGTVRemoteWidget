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
        status = .connecting

        let normalizedMac = mac.uppercased()
        var credentials = TVCredentials(ipAddress: ip, macAddress: normalizedMac)
        if let stored: TVCredentials = try? keychain.load(TVCredentials.self, service: Constants.keychainService, account: Constants.keychainAccount),
           stored.ipAddress == ip,
           stored.macAddress.uppercased() == normalizedMac {
            credentials.clientKey = stored.clientKey
        }
        currentCredentials = credentials

        do {
            try await webSocket.connect(to: ip)
            let result = try await webSocket.register(manifest: manifest, clientKey: credentials.clientKey)
            switch result {
            case .success(let clientKey):
                credentials.clientKey = clientKey
                saveCredentials(credentials)
                currentCredentials = credentials
                status = .connected
                return nil
            case .pairingRequired(let code):
                status = .pairingRequired(code: code)
                return code
            }
        } catch {
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

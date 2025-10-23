import Foundation

public final class LGTVControlManager {
    public static let shared = LGTVControlManager()

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
        self.currentCredentials = TVCredentials(ipAddress: ip, macAddress: mac)
        try await webSocket.connect(to: ip)
        status = .connected
        return nil // Pairing flow implemented in Step 4
    }

    public func sendCommand(_ command: String, parameters: [String: Any]? = nil) async throws {
        guard case .connected = status else { throw NSError(domain: "LGTVControl", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"]) }
        var payload: [String: AnyCodable]? = nil
        if let parameters {
            var dict: [String: AnyCodable] = [:]
            for (k, v) in parameters { dict[k] = AnyCodable(v) }
            payload = dict
        }
        let req = SSAPRequest(type: "request", uri: command, payload: payload)
        try await webSocket.send(req)
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
}

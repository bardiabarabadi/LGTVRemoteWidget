import Foundation
import LGTVControl

actor RemotePanelActionHandler {
    static let shared = RemotePanelActionHandler()

    private let controlManager = LGTVControlManager.shared

    func sendVolumeUp() async throws {
        try await sendCommand(uri: "ssap://audio/volumeUp")
    }

    // MARK: - Internal helpers

    private func sendCommand(uri: String, parameters: [String: Any]? = nil) async throws {
        let credentials = try loadCredentials()

        var didConnect = false
        defer {
            if didConnect {
                controlManager.disconnect()
            }
        }

        do {
            if let pairingCode = try await controlManager.connect(ip: credentials.ipAddress, mac: credentials.macAddress) {
                controlManager.disconnect()
                throw RemotePanelError.pairingRequired(code: pairingCode)
            }
            didConnect = true
            try await controlManager.sendCommand(uri, parameters: parameters)
        } catch {
            throw RemotePanelError.wrap(error)
        }
    }

    private func loadCredentials() throws -> TVCredentials {
        guard let credentials = controlManager.loadCredentials() else {
            throw RemotePanelError.missingCredentials
        }
        return credentials
    }
}

enum RemotePanelError: Error, LocalizedError {
    case missingCredentials
    case pairingRequired(code: String?)
    case underlying(Error)

    static func wrap(_ error: Error) -> RemotePanelError {
        if let remoteError = error as? RemotePanelError {
            return remoteError
        }

        if let controlError = error as? LGTVControlManager.ControlError {
            switch controlError {
            case .missingCredentials:
                return .missingCredentials
            case .pairingFailed, .invalidPairingCode:
                return .pairingRequired(code: nil)
            case .notConnected:
                return .underlying(controlError)
            }
        }

        return .underlying(error)
    }

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "TV credentials are missing. Open the app to pair with your TV."
        case let .pairingRequired(code):
            if let code {
                return "Pairing required. Enter the code \(code) in the app."
            }
            return "Pairing required. Open the app to complete setup."
        case let .underlying(error):
            return error.localizedDescription
        }
    }
}

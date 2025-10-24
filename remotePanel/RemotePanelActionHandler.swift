import Foundation
import LGTVControl
import OSLog

actor RemotePanelActionHandler {
    static let shared = RemotePanelActionHandler()

    private let controlManager = LGTVControlManager.shared
    private var disconnectTask: Task<Void, Never>?
    private let disconnectDelayNanoseconds: UInt64 = 1 * 1_000_000_000
    private let logger = Logger(subsystem: "com.DaraConsultingInc.LGTVRemoteWidget", category: "RemotePanelAction")

    func sendVolumeUp() async throws {
        try await sendCommand(uri: "ssap://audio/volumeUp")
    }

    func sendVolumeDown() async throws {
        try await sendCommand(uri: "ssap://audio/volumeDown")
    }

    func sendPowerOff() async throws {
        try await sendCommand(uri: "ssap://system/turnOff")
    }

    func sendPowerOn() async throws {
        logger.log("Power on intent started")
        let credentials = try loadCredentials()
        do {
            try await controlManager.wakeTV(mac: credentials.macAddress, ip: credentials.ipAddress)
            logger.log("Power on completed successfully")
        } catch {
            logger.error("Power on failed: \(error.localizedDescription, privacy: .public)")
            throw RemotePanelError.wrap(error)
        }
    }

    func sendPlayPause() async throws {
        do {
            try await sendCommand(uri: "ssap://media.controls/playPause")
        } catch {
            logger.warning("playPause command failed, attempting toggle fallback")
            do {
                try await sendCommand(uri: "ssap://media.controls/togglePlayPause")
            } catch {
                logger.error("Play/pause fallback failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
    }

    func sendNavigation(_ button: PointerInputClient.Button) async throws {
        try await performCommandBlock(connectWithPointer: true) { manager in
            try await manager.sendButton(button)
        }
    }

    func sendOk() async throws {
        try await performCommandBlock(connectWithPointer: true) { manager in
            try await manager.sendClick()
        }
    }

    func launchApp(id: String) async throws {
        try await sendCommand(uri: "ssap://system.launcher/launch", parameters: ["id": id])
    }

    func switchInput(id: String) async throws {
        try await sendCommand(uri: "ssap://tv/switchInput", parameters: ["inputId": id])
    }

    // MARK: - Internal helpers

    private func sendCommand(uri: String, parameters: [String: Any]? = nil) async throws {
        let start = Date()
        logger.log("Intent started: \(uri, privacy: .public)")

        let credentials = try loadCredentials()
        let connectionStart = Date()
        let alreadyConnected = try await connectIfNeeded(credentials: credentials, enablePointer: false)
        let connectDuration = Date().timeIntervalSince(connectionStart)
        logger.log("Connection ready in \(connectDuration, format: .fixed(precision: 2))s (reused: \(alreadyConnected, privacy: .public))")

        do {
            try await controlManager.sendCommand(uri, parameters: parameters)
        } catch {
            if case LGTVControlManager.ControlError.notConnected = error {
                controlManager.disconnect()

                let reconnectStart = Date()
                let reused = try await connectIfNeeded(credentials: credentials, enablePointer: false)
                let reconnectDuration = Date().timeIntervalSince(reconnectStart)
                logger.log("Reconnect completed in \(reconnectDuration, format: .fixed(precision: 2))s (reused: \(reused, privacy: .public))")

                do {
                    try await controlManager.sendCommand(uri, parameters: parameters)
                } catch {
                    throw RemotePanelError.wrap(error)
                }
            } else {
                throw RemotePanelError.wrap(error)
            }
        }

        scheduleDisconnect(startingFromConnected: alreadyConnected)
        let totalDuration = Date().timeIntervalSince(start)
        logger.log("Intent finished in \(totalDuration, format: .fixed(precision: 2))s")
    }

    private func performCommandBlock(connectWithPointer: Bool, block: @escaping (LGTVControlManager) async throws -> Void) async throws {
        let start = Date()
        logger.log("Intent started: block")

        let credentials = try loadCredentials()
        let connectionStart = Date()
        let alreadyConnected = try await connectIfNeeded(credentials: credentials, enablePointer: connectWithPointer)
        let connectDuration = Date().timeIntervalSince(connectionStart)
        logger.log("Connection ready in \(connectDuration, format: .fixed(precision: 2))s (reused: \(alreadyConnected, privacy: .public))")

        do {
            try await block(controlManager)
        } catch {
            if case LGTVControlManager.ControlError.notConnected = error {
                controlManager.disconnect()

                let reconnectStart = Date()
                let reused = try await connectIfNeeded(credentials: credentials, enablePointer: connectWithPointer)
                let reconnectDuration = Date().timeIntervalSince(reconnectStart)
                logger.log("Reconnect completed in \(reconnectDuration, format: .fixed(precision: 2))s (reused: \(reused, privacy: .public))")

                do {
                    try await block(controlManager)
                } catch {
                    throw RemotePanelError.wrap(error)
                }
            } else {
                throw RemotePanelError.wrap(error)
            }
        }

        scheduleDisconnect(startingFromConnected: alreadyConnected)
        let totalDuration = Date().timeIntervalSince(start)
        logger.log("Intent finished in \(totalDuration, format: .fixed(precision: 2))s")
    }

    private func loadCredentials() throws -> TVCredentials {
        guard let credentials = controlManager.loadCredentials() else {
            throw RemotePanelError.missingCredentials
        }
        return credentials
    }

    @discardableResult
    private func connectIfNeeded(credentials: TVCredentials, enablePointer: Bool) async throws -> Bool {
        disconnectTask?.cancel()

        if case .connected = controlManager.getConnectionStatus() {
            logger.log("Reusing existing connection")
            return true
        }

        let connectStart = Date()
        logger.log("Connecting to TV")
        do {
            if let pairingCode = try await controlManager.connect(ip: credentials.ipAddress, mac: credentials.macAddress, enablePointer: enablePointer) {
                controlManager.disconnect()
                throw RemotePanelError.pairingRequired(code: pairingCode)
            }
        } catch {
            throw RemotePanelError.wrap(error)
        }
        logger.log("Initial connection completed in \(Date().timeIntervalSince(connectStart), format: .fixed(precision: 2))s")
        return false
    }

    private func scheduleDisconnect(startingFromConnected _: Bool) {
        disconnectTask?.cancel()
        disconnectTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.disconnectDelayNanoseconds
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await self.performDisconnect()
        }
    }

    private func performDisconnect() {
        disconnectTask = nil
        controlManager.disconnect()
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

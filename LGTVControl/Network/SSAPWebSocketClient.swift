import Foundation

public final class SSAPWebSocketClient: NSObject {
    public enum ClientError: Error, LocalizedError {
        case invalidURL
        case notConnected
        case sendFailed
        case receiveFailed
        case alreadyConnecting
        case invalidResponse
        case registrationInProgress
        case timeout
        case serverError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid WebSocket URL"
            case .notConnected: return "WebSocket is not connected"
            case .sendFailed: return "Failed to send message"
            case .receiveFailed: return "Failed to receive message"
            case .alreadyConnecting: return "A connection is already in progress"
            case .invalidResponse: return "Received an unexpected response from the TV"
            case .registrationInProgress: return "A registration attempt is already running"
            case .timeout: return "Timed out waiting for a response from the TV"
            case .serverError(let message): return message
            }
        }
    }

    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private var isConnecting = false
    private let queue = DispatchQueue(label: "SSAPWebSocketClient.queue")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var pendingResponses: [String: CheckedContinuation<SSAPResponse, Error>] = [:]
    private var registerContinuation: CheckedContinuation<SSAPRegistrationResult, Error>?
    private var registerMessageHandler: ((SSAPResponse) -> Bool)?
    private var registerRequestId: String?
    private var registerTimeoutWorkItem: DispatchWorkItem?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var connectTimeoutWorkItem: DispatchWorkItem?

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    public func connect(to ipAddress: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                if self.isConnecting {
                    cont.resume(throwing: ClientError.alreadyConnecting)
                    return
                }
                guard let url = URL(string: "ws://\(ipAddress):3000/") else {
                    cont.resume(throwing: ClientError.invalidURL)
                    return
                }

                self.resetState()
                self.isConnecting = true
                self.task = self.session.webSocketTask(with: url)
                self.task?.resume()
                self.receiveLoop()

                self.connectContinuation = cont
                self.connectTimeoutWorkItem?.cancel()
                let timeoutItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.queue.async {
                        self.completeConnect(with: .failure(ClientError.timeout))
                    }
                }
                self.connectTimeoutWorkItem = timeoutItem
                self.queue.asyncAfter(deadline: .now() + 10, execute: timeoutItem)
            }
        }
    }

    public func disconnect() {
        queue.async {
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.failAllPending(with: ClientError.notConnected)
            self.resetState(clearConnection: false)
            self.completeConnect(with: .failure(ClientError.notConnected))
        }
    }

    public func register(manifest: SSAPManifest, clientKey: String?) async throws -> SSAPRegistrationResult {
        let payload = SSAPRegisterPayload(forcePairing: false, pairingType: "PROMPT", manifest: manifest, clientKey: clientKey, pin: nil)
        return try await performRegister(with: payload)
    }

    public func submitPairingCode(_ code: String, manifest: SSAPManifest, clientKey: String?) async throws -> SSAPRegistrationResult {
        let payload = SSAPRegisterPayload(forcePairing: false, pairingType: "PROMPT", manifest: manifest, clientKey: clientKey, pin: code)
        return try await performRegister(with: payload)
    }

    @discardableResult
    public func sendRequest(_ request: SSAPRequest, awaitResponse: Bool = true) async throws -> SSAPResponse? {
        if awaitResponse {
            return try await sendRequestForResponse(request)
        } else {
            let data = try encodeMessage(request)
            try await send(data: data)
            return nil
        }
    }

    // MARK: - Private helpers

    private func performRegister(with payload: SSAPRegisterPayload) async throws -> SSAPRegistrationResult {
        let request = SSAPRegisterRequest(payload: payload)
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.task != nil else {
                    continuation.resume(throwing: ClientError.notConnected)
                    return
                }
                if self.registerContinuation != nil {
                    continuation.resume(throwing: ClientError.registrationInProgress)
                    return
                }

                self.registerContinuation = continuation
                self.registerRequestId = request.id
                self.registerMessageHandler = { [weak self] response in
                    guard let self else { return false }
                    return self.handleRegisterResponse(response, requestId: request.id)
                }

                self.registerTimeoutWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.queue.async {
                        self.finishRegister(with: .failure(ClientError.timeout))
                    }
                }
                self.registerTimeoutWorkItem = workItem
                self.queue.asyncAfter(deadline: .now() + 10, execute: workItem)

                do {
                    let data = try self.encodeMessage(request)
                    Task {
                        do {
                            try await self.send(data: data)
                        } catch {
                            self.queue.async {
                                self.finishRegister(with: .failure(error))
                            }
                        }
                    }
                } catch {
                    self.finishRegister(with: .failure(error))
                }
            }
        }
    }

    private func handleRegisterResponse(_ response: SSAPResponse, requestId: String) -> Bool {
        guard registerRequestId == requestId else { return false }

        if let id = response.id, id != requestId {
            return false
        }

        if let error = response.error {
            finishRegister(with: .failure(ClientError.serverError(error)))
            return true
        }

        if let type = response.type {
            switch type {
            case "error":
                let message = response.error ?? "Unknown registration error"
                finishRegister(with: .failure(ClientError.serverError(message)))
                return true
            case "response":
                if let clientKey = extractClientKey(from: response) {
                    finishRegister(with: .success(.success(clientKey: clientKey)))
                    return true
                }
                if let returnValue = response.returnValue, returnValue == false {
                    finishRegister(with: .failure(ClientError.invalidResponse))
                    return true
                }
                if let pairingTypeValue = response.payload?["pairingType"]?.value as? String {
                    let pairingCode = response.payload?["pin"]?.value as? String
                    finishRegister(with: .success(.pairingRequired(code: pairingCode)))
                    return true
                }
                return true
            case "registered":
                if let clientKey = extractClientKey(from: response) {
                    finishRegister(with: .success(.success(clientKey: clientKey)))
                } else {
                    finishRegister(with: .failure(ClientError.invalidResponse))
                }
                return true
            default:
                break
            }
        }

        return false
    }

    private func extractClientKey(from response: SSAPResponse) -> String? {
        if let clientKey = response.payload?["client-key"]?.value as? String {
            return clientKey
        }
        if let payload = response.payload?["clientKey"]?.value as? String {
            return payload
        }
        return nil
    }

    private func finishRegister(with result: Result<SSAPRegistrationResult, Error>) {
        let continuation = registerContinuation
        registerContinuation = nil
        registerMessageHandler = nil
        registerRequestId = nil
        registerTimeoutWorkItem?.cancel()
        registerTimeoutWorkItem = nil
        switch result {
        case .success(let value):
            continuation?.resume(returning: value)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    private func encodeMessage<T: Encodable>(_ message: T) throws -> Data {
        try encoder.encode(message)
    }

    private func send(data: Data) async throws {
        guard let task else { throw ClientError.notConnected }
        let message: URLSessionWebSocketTask.Message
        if let text = String(data: data, encoding: .utf8) {
            message = .string(text)
        } else {
            message = .data(data)
        }
        do {
            try await task.send(message)
        } catch {
            throw ClientError.sendFailed
        }
    }

    private func sendRequestForResponse(_ request: SSAPRequest) async throws -> SSAPResponse {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.task != nil else {
                    continuation.resume(throwing: ClientError.notConnected)
                    return
                }
                if self.pendingResponses[request.id] != nil {
                    continuation.resume(throwing: ClientError.alreadyConnecting)
                    return
                }

                let messageData: Data
                do {
                    messageData = try self.encodeMessage(request)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                self.pendingResponses[request.id] = continuation
                Task {
                    do {
                        try await self.send(data: messageData)
                    } catch {
                        self.queue.async {
                            if let cont = self.pendingResponses.removeValue(forKey: request.id) {
                                cont.resume(throwing: error)
                            }
                        }
                    }
                }
            }
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.queue.async {
                    self.handle(message)
                }
                self.receiveLoop()
            case .failure:
                self.queue.async {
                    self.failAllPending(with: ClientError.receiveFailed)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let text):
            data = Data(text.utf8)
        @unknown default:
            return
        }

        guard let response = try? decoder.decode(SSAPResponse.self, from: data) else {
            return
        }

        if let handler = registerMessageHandler, handler(response) {
            return
        }

        if let id = response.id, let cont = pendingResponses.removeValue(forKey: id) {
            cont.resume(returning: response)
            return
        }
    }

    private func failAllPending(with error: Error) {
        pendingResponses.forEach { $0.value.resume(throwing: error) }
        pendingResponses.removeAll()
        finishRegister(with: .failure(error))
        completeConnect(with: .failure(error))
    }

    private func resetState(clearConnection: Bool = true) {
        pendingResponses.removeAll()
        registerContinuation = nil
        registerMessageHandler = nil
        registerRequestId = nil
        registerTimeoutWorkItem?.cancel()
        registerTimeoutWorkItem = nil
        connectTimeoutWorkItem?.cancel()
        connectTimeoutWorkItem = nil
        connectContinuation = nil
        if clearConnection {
            task = nil
        }
    }

    private func completeConnect(with result: Result<Void, Error>) {
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        connectTimeoutWorkItem?.cancel()
        connectTimeoutWorkItem = nil
        isConnecting = false
        switch result {
        case .success:
            continuation.resume(returning: ())
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension SSAPWebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async {
            self.completeConnect(with: .success(()))
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.async {
            self.failAllPending(with: ClientError.notConnected)
            self.resetState()
        }
    }
}

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
    private var hasReceivedHello = false
    private var pendingRegistrationPayload: SSAPRegisterPayload?

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        print("[SSAPWebSocket] 🔧 WebSocket client initialized")
    }

    public func connect(to ipAddress: String, useSecure: Bool = true) async throws {
        let scheme = useSecure ? "wss" : "ws"
        let port = useSecure ? 3001 : 3000
        print("[SSAPWebSocket] 🔵 Starting connection to \(scheme)://\(ipAddress):\(port)/")
        
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                if self.isConnecting {
                    print("[SSAPWebSocket] ⚠️ Already connecting, rejecting new connection attempt")
                    cont.resume(throwing: ClientError.alreadyConnecting)
                    return
                }
                guard let url = URL(string: "\(scheme)://\(ipAddress):\(port)/") else {
                    print("[SSAPWebSocket] ❌ Invalid URL: \(scheme)://\(ipAddress):\(port)/")
                    cont.resume(throwing: ClientError.invalidURL)
                    return
                }

                print("[SSAPWebSocket] 🔄 Resetting state and preparing connection")
                self.resetState()
                self.isConnecting = true
                self.connectContinuation = cont
                
                print("[SSAPWebSocket] 🚀 Creating WebSocket task with URL: \(url.absoluteString)")
                
                // For secure WebSocket (wss), we need to handle self-signed certificates
                // Create URLRequest to allow setting up the connection properly
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                
                self.task = self.session.webSocketTask(with: request)
                print("[SSAPWebSocket] 📡 WebSocket task created (\(useSecure ? "secure WSS" : "insecure WS")), calling resume()")
                self.task?.resume()
                print("[SSAPWebSocket] ✅ Task resumed")
                
                // Set connection timeout
                self.connectTimeoutWorkItem?.cancel()
                let timeoutItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.queue.async {
                        if self.isConnecting {
                            print("[SSAPWebSocket] ⏱️ Connection timeout after 10 seconds")
                            self.task?.cancel(with: .goingAway, reason: nil)
                            self.completeConnect(with: .failure(ClientError.timeout))
                        }
                    }
                }
                self.connectTimeoutWorkItem = timeoutItem
                self.queue.asyncAfter(deadline: .now() + 10, execute: timeoutItem)
                print("[SSAPWebSocket] ⏲️ Connection timeout set for 10 seconds")
            }
        }
    }

    public func disconnect() {
        print("[SSAPWebSocket] 🔴 Disconnect requested")
        queue.async {
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
            self.failAllPending(with: ClientError.notConnected)
            self.resetState(clearConnection: false)
            self.completeConnect(with: .failure(ClientError.notConnected))
            print("[SSAPWebSocket] ✅ Disconnected")
        }
    }

    public func register(manifest: SSAPManifest, clientKey: String?) async throws -> SSAPRegistrationResult {
        print("[SSAPWebSocket] 📝 Register called - waiting for TV 'hello' message first...")
        let payload = SSAPRegisterPayload(forcePairing: false, pairingType: "PROMPT", manifest: manifest, clientKey: clientKey, pin: nil)
        
        // If we've already received hello, send immediately
        // Otherwise, store the payload and it will be sent when hello arrives
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
        print("[SSAPWebSocket] 📝 Preparing registration request")
        print("[SSAPWebSocket] 📝 Client key present: \(payload.clientKey != nil)")
        print("[SSAPWebSocket] 📝 PIN present: \(payload.pin != nil)")
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.task != nil else {
                    print("[SSAPWebSocket] ❌ Cannot register: not connected")
                    continuation.resume(throwing: ClientError.notConnected)
                    return
                }
                if self.registerContinuation != nil {
                    print("[SSAPWebSocket] ⚠️ Registration already in progress")
                    continuation.resume(throwing: ClientError.registrationInProgress)
                    return
                }

                print("[SSAPWebSocket] 🔐 Setting up registration handlers")
                self.registerContinuation = continuation
                
                self.registerTimeoutWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.queue.async {
                        print("[SSAPWebSocket] ⏱️ Registration timeout after 15 seconds (waiting for hello or response)")
                        self.finishRegister(with: .failure(ClientError.timeout))
                    }
                }
                self.registerTimeoutWorkItem = workItem
                self.queue.asyncAfter(deadline: .now() + 15, execute: workItem)
                print("[SSAPWebSocket] ⏲️ Registration timeout set for 15 seconds")

                // Check if we've already received hello
                if self.hasReceivedHello {
                    print("[SSAPWebSocket] ✅ Already received 'hello', sending registration immediately")
                    Task {
                        do {
                            try await self.sendRegistrationRequest(payload)
                        } catch {
                            print("[SSAPWebSocket] ❌ Failed to send registration: \(error)")
                            self.queue.async {
                                self.finishRegister(with: .failure(error))
                            }
                        }
                    }
                } else {
                    // webOS 23 might not send hello - try sending registration after a brief delay
                    print("[SSAPWebSocket] ⏳ Waiting 2 seconds for TV 'hello' message...")
                    print("[SSAPWebSocket] (If no hello received, will send registration anyway - webOS 23 behavior)")
                    self.pendingRegistrationPayload = payload
                    
                    // Set a shorter timer to send registration if no hello received
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                        self.queue.async {
                            if let pendingPayload = self.pendingRegistrationPayload {
                                print("[SSAPWebSocket] ⚠️ No 'hello' received after 2 seconds")
                                print("[SSAPWebSocket] 🚀 Sending registration anyway (webOS 23+ may not send hello)")
                                self.pendingRegistrationPayload = nil
                                Task {
                                    do {
                                        try await self.sendRegistrationRequest(pendingPayload)
                                    } catch {
                                        print("[SSAPWebSocket] ❌ Failed to send registration: \(error)")
                                        self.queue.async {
                                            self.finishRegister(with: .failure(error))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sendRegistrationRequest(_ payload: SSAPRegisterPayload) async throws {
        let request = SSAPRegisterRequest(payload: payload)
        print("[SSAPWebSocket] 📝 Creating registration request with id: \(request.id)")
        
        await queue.async {
            self.registerRequestId = request.id
            self.registerMessageHandler = { [weak self] response in
                guard let self else { return false }
                return self.handleRegisterResponse(response, requestId: request.id)
            }
        }
        
        let data = try encodeMessage(request)
        print("[SSAPWebSocket] 📤 Sending registration message")
        try await send(data: data)
        print("[SSAPWebSocket] ✅ Registration message sent, waiting for response...")
    }

    private func handleRegisterResponse(_ response: SSAPResponse, requestId: String) -> Bool {
        print("[SSAPWebSocket] 🔍 Checking if response matches registration request")
        guard registerRequestId == requestId else {
            print("[SSAPWebSocket] ⚠️ Register request ID mismatch")
            return false
        }

        if let id = response.id, id != requestId {
            print("[SSAPWebSocket] ⚠️ Response ID (\(id)) doesn't match request ID (\(requestId))")
            return false
        }

        if let error = response.error {
            print("[SSAPWebSocket] ❌ Registration error: \(error)")
            finishRegister(with: .failure(ClientError.serverError(error)))
            return true
        }

        if let type = response.type {
            print("[SSAPWebSocket] 📨 Registration response type: \(type)")
            switch type {
            case "error":
                let message = response.error ?? "Unknown registration error"
                print("[SSAPWebSocket] ❌ Registration failed: \(message)")
                finishRegister(with: .failure(ClientError.serverError(message)))
                return true
            case "response":
                if let clientKey = extractClientKey(from: response) {
                    print("[SSAPWebSocket] 🔑 Registration successful! Client key received")
                    finishRegister(with: .success(.success(clientKey: clientKey)))
                    return true
                }
                if let returnValue = response.returnValue, returnValue == false {
                    print("[SSAPWebSocket] ❌ Registration rejected (returnValue=false)")
                    finishRegister(with: .failure(ClientError.invalidResponse))
                    return true
                }
                if let pairingTypeValue = response.payload?["pairingType"]?.value as? String {
                    let pairingCode = response.payload?["pin"]?.value as? String
                    print("[SSAPWebSocket] 🔐 Pairing required - code: \(pairingCode ?? "PROMPT mode - user must accept on TV")")
                    
                    if pairingCode != nil {
                        // PIN mode - return and wait for user to enter code
                        finishRegister(with: .success(.pairingRequired(code: pairingCode)))
                        return true
                    } else {
                        // PROMPT mode - don't finish, keep waiting for approval
                        print("[SSAPWebSocket] ⏳ PROMPT mode - waiting for user to accept on TV...")
                        print("[SSAPWebSocket] (Will receive 'registered' message when approved)")
                        // Don't call finishRegister - continue waiting for next message
                        return true
                    }
                }
                print("[SSAPWebSocket] ℹ️ Response handled (no specific action needed)")
                return true
            case "registered":
                if let clientKey = extractClientKey(from: response) {
                    print("[SSAPWebSocket] 🔑 Registration successful! Client key received (registered type)")
                    finishRegister(with: .success(.success(clientKey: clientKey)))
                } else {
                    print("[SSAPWebSocket] ❌ Registered response missing client key")
                    finishRegister(with: .failure(ClientError.invalidResponse))
                }
                return true
            default:
                print("[SSAPWebSocket] ⚠️ Unknown registration response type: \(type)")
                break
            }
        }

        print("[SSAPWebSocket] ⚠️ Registration response not handled")
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
        print("[SSAPWebSocket] 🏁 Finishing registration")
        let continuation = registerContinuation
        registerContinuation = nil
        registerMessageHandler = nil
        registerRequestId = nil
        registerTimeoutWorkItem?.cancel()
        registerTimeoutWorkItem = nil
        switch result {
        case .success(let value):
            print("[SSAPWebSocket] ✅ Registration completed successfully")
            continuation?.resume(returning: value)
        case .failure(let error):
            print("[SSAPWebSocket] ❌ Registration failed: \(error.localizedDescription)")
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
            print("[SSAPWebSocket] Sending message: \(text)")
            message = .string(text)
        } else {
            print("[SSAPWebSocket] Sending binary data (\(data.count) bytes)")
            message = .data(data)
        }
        do {
            try await task.send(message)
            print("[SSAPWebSocket] Message sent successfully")
        } catch {
            print("[SSAPWebSocket] Failed to send message: \(error)")
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
        print("[SSAPWebSocket] 👂 Starting receive loop (waiting for messages)")
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                print("[SSAPWebSocket] 📥 Message received")
                self.queue.async {
                    self.handle(message)
                }
                self.receiveLoop()
            case .failure(let error):
                print("[SSAPWebSocket] ❌ Receive loop failed: \(error.localizedDescription)")
                self.queue.async {
                    // Provide more context about the receive failure
                    let wrappedError = ClientError.serverError("Connection lost: \(error.localizedDescription)")
                    self.failAllPending(with: wrappedError)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):
            print("[SSAPWebSocket] Received binary data (\(d.count) bytes)")
            data = d
        case .string(let text):
            print("[SSAPWebSocket] Received message: \(text)")
            data = Data(text.utf8)
        @unknown default:
            print("[SSAPWebSocket] Received unknown message type")
            return
        }

        guard let response = try? decoder.decode(SSAPResponse.self, from: data) else {
            print("[SSAPWebSocket] Failed to decode response")
            return
        }

        print("[SSAPWebSocket] Decoded response - type: \(response.type ?? "nil"), id: \(response.id ?? "nil")")

        // Handle the initial "hello" message from the TV
        if let type = response.type, type == "hello" {
            print("[SSAPWebSocket] 👋 Received 'hello' from TV!")
            if let payload = response.payload {
                print("[SSAPWebSocket] TV Info - Protocol: \(payload["protocolVersion"]?.value ?? "unknown"), Device: \(payload["deviceType"]?.value ?? "unknown"), OS: \(payload["deviceOS"]?.value ?? "unknown") \(payload["deviceOSVersion"]?.value ?? "unknown")")
            }
            hasReceivedHello = true
            
            // If we have a pending registration, send it now
            if let pendingPayload = pendingRegistrationPayload {
                print("[SSAPWebSocket] 🚀 Sending pending registration request now that we have hello")
                pendingRegistrationPayload = nil
                Task {
                    do {
                        try await self.sendRegistrationRequest(pendingPayload)
                    } catch {
                        print("[SSAPWebSocket] ❌ Failed to send pending registration: \(error)")
                        self.queue.async {
                            self.finishRegister(with: .failure(error))
                        }
                    }
                }
            }
            return
        }

        if let handler = registerMessageHandler, handler(response) {
            print("[SSAPWebSocket] Handled by registration handler")
            return
        }

        if let id = response.id, let cont = pendingResponses.removeValue(forKey: id) {
            print("[SSAPWebSocket] Resuming pending response for id: \(id)")
            cont.resume(returning: response)
            return
        }
        
        print("[SSAPWebSocket] No handler found for response")
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
        hasReceivedHello = false
        pendingRegistrationPayload = nil
        if clearConnection {
            task = nil
        }
    }

    private func completeConnect(with result: Result<Void, Error>) {
        guard let continuation = connectContinuation else {
            print("[SSAPWebSocket] ⚠️ CompleteConnect called but no continuation found")
            return
        }
        print("[SSAPWebSocket] 🏁 Completing connection")
        connectContinuation = nil
        connectTimeoutWorkItem?.cancel()
        connectTimeoutWorkItem = nil
        isConnecting = false
        switch result {
        case .success:
            print("[SSAPWebSocket] ✅ Connection established successfully")
            continuation.resume(returning: ())
        case .failure(let error):
            print("[SSAPWebSocket] ❌ Connection failed: \(error.localizedDescription)")
            continuation.resume(throwing: error)
        }
    }
}

extension SSAPWebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocolString: String?) {
        print("[SSAPWebSocket] ✅ DELEGATE: Connection opened with protocol: \(protocolString ?? "none")")
        queue.async {
            // Start receiving messages only after connection is confirmed open
            print("[SSAPWebSocket] 🎯 Connection confirmed, starting receive loop")
            self.receiveLoop()
            self.completeConnect(with: .success(()))
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "no reason provided"
        print("[SSAPWebSocket] 🔴 DELEGATE: Connection closed - code: \(closeCode.rawValue), reason: \(reasonString)")
        queue.async {
            let errorMessage = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "Connection closed by server"
            let error = ClientError.serverError(errorMessage)
            self.failAllPending(with: error)
            self.resetState()
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[SSAPWebSocket] ❌ DELEGATE: Task completed with error: \(error.localizedDescription)")
            queue.async {
                self.failAllPending(with: error)
            }
        } else {
            print("[SSAPWebSocket] ℹ️ DELEGATE: Task completed without error")
        }
    }
    
    // Handle authentication challenges for self-signed certificates
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("[SSAPWebSocket] 🔐 DELEGATE: Received authentication challenge")
        print("[SSAPWebSocket] 🔐 Challenge method: \(challenge.protectionSpace.authenticationMethod)")
        
        // Accept self-signed certificates for local TV connection
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            print("[SSAPWebSocket] ✅ Accepting self-signed certificate for local TV")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("[SSAPWebSocket] ⚠️ Using default handling for challenge")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

import Foundation

/// Client for LG webOS pointer input socket (for navigation buttons)
/// webOS 22/23 require a separate WebSocket connection for arrow keys, OK, etc.
public final class PointerInputClient: NSObject {
    private var task: URLSessionWebSocketTask?
    private let queue = DispatchQueue(label: "com.lgtv.pointerinput", qos: .userInitiated)
    private var isConnected = false
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private let connectionTimeoutNanoseconds: UInt64 = 5 * 1_000_000_000
    
    public override init() {
        super.init()
    }
    
    public func connect(socketPath: String) async throws {
        guard let url = URL(string: socketPath) else {
            throw PointerInputError.invalidSocketPath
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let newTask = session.webSocketTask(with: request)
        
        self.task = newTask
        newTask.resume()
        
        // Start receiving messages to keep connection alive
        receiveMessage(task: newTask)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                if self.connectionContinuation != nil {
                    continuation.resume(throwing: PointerInputError.alreadyConnecting)
                    return
                }

                self.connectionContinuation = continuation
                self.connectionTimeoutTask?.cancel()
                self.connectionTimeoutTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await Task.sleep(nanoseconds: self.connectionTimeoutNanoseconds)
                    } catch {
                        return
                    }
                    self.queue.async {
                        if let continuation = self.connectionContinuation {
                            self.connectionContinuation = nil
                            continuation.resume(throwing: PointerInputError.connectTimeout)
                        }
                        self.connectionTimeoutTask = nil
                        self.task?.cancel(with: .goingAway, reason: nil)
                    }
                }
            }
        }

        isConnected = true
    }
    
    private func receiveMessage(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            if case .success = result {
                self?.receiveMessage(task: task)
            } else {
                self?.isConnected = false
            }
        }
    }
    
    public func sendButton(_ button: Button) async throws {
        guard isConnected, let task = task else {
            throw PointerInputError.notConnected
        }
        
        let message = "type:button\nname:\(button.rawValue)\n\n"
        try await task.send(.string(message))
    }
    
    public func sendClick() async throws {
        guard isConnected, let task = task else {
            throw PointerInputError.notConnected
        }
        
        let message = "type:click\n\n"
        try await task.send(.string(message))
    }
    
    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        queue.async {
            self.connectionTimeoutTask?.cancel()
            self.connectionTimeoutTask = nil
            if let continuation = self.connectionContinuation {
                self.connectionContinuation = nil
                continuation.resume(throwing: PointerInputError.notConnected)
            }
        }
    }
    
    // MARK: - Button Types
    
    public enum Button: String {
        case up = "UP"
        case down = "DOWN"
        case left = "LEFT"
        case right = "RIGHT"
        case enter = "ENTER"
        case back = "BACK"
        case home = "HOME"
        case exit = "EXIT"
        case info = "INFO"
        case menu = "MENU"
        // Playback controls
        case play = "PLAY"
        case pause = "PAUSE"
        case stop = "STOP"
        case rewind = "REWIND"
        case fastForward = "FASTFORWARD"
    }
    
    public enum PointerInputError: Error, LocalizedError {
        case notConnected
        case invalidSocketPath
        case sendFailed(String)
        case connectTimeout
        case alreadyConnecting
        
        public var errorDescription: String? {
            switch self {
            case .notConnected: return "Pointer socket not connected"
            case .invalidSocketPath: return "Invalid pointer socket path"
            case .sendFailed(let msg): return "Failed to send button: \(msg)"
            case .connectTimeout: return "Pointer socket connection timed out"
            case .alreadyConnecting: return "Pointer socket connection already in progress"
            }
        }
    }
}

extension PointerInputClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async {
            self.isConnected = true
            self.connectionTimeoutTask?.cancel()
            self.connectionTimeoutTask = nil
            if let continuation = self.connectionContinuation {
                self.connectionContinuation = nil
                continuation.resume()
            }
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        queue.async {
            self.connectionTimeoutTask?.cancel()
            self.connectionTimeoutTask = nil
            if let continuation = self.connectionContinuation {
                self.connectionContinuation = nil
                continuation.resume(throwing: PointerInputError.notConnected)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: trust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

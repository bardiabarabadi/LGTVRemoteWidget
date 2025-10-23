import Foundation

public final class SSAPWebSocketClient: NSObject {
    public enum ClientError: Error, LocalizedError {
        case invalidURL
        case notConnected
        case sendFailed
        case receiveFailed
        case alreadyConnecting

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid WebSocket URL"
            case .notConnected: return "WebSocket is not connected"
            case .sendFailed: return "Failed to send message"
            case .receiveFailed: return "Failed to receive message"
            case .alreadyConnecting: return "A connection is already in progress"
            }
        }
    }

    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private var isConnecting = false
    private let queue = DispatchQueue(label: "SSAPWebSocketClient.queue")

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    public func connect(to ipAddress: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                if self.isConnecting {
                    cont.resume(throwing: ClientError.alreadyConnecting)
                    return
                }
                guard let url = URL(string: "ws://\(ipAddress):3000/") else {
                    cont.resume(throwing: ClientError.invalidURL)
                    return
                }
                self.isConnecting = true
                self.task = self.session.webSocketTask(with: url)
                self.task?.resume()
                // Start receive loop
                self.receiveLoop()
                // There's no completion for resume; assume connected shortly after
                // Give a small delay to allow connection to establish
                self.queue.asyncAfter(deadline: .now() + 0.2) {
                    self.isConnecting = false
                    cont.resume()
                }
            }
        }
    }

    public func disconnect() {
        queue.async {
            self.task?.cancel(with: .goingAway, reason: nil)
            self.task = nil
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                // For step 3 we don't route messages yet; continue the loop
                self.receiveLoop()
            case .failure:
                break
            }
        }
    }

    public func send<T: Encodable>(_ payload: T) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        guard let task = task else { throw ClientError.notConnected }
        try await task.send(.data(data))
    }
}

extension SSAPWebSocketClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // No-op for now
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        // No-op for now
    }
}

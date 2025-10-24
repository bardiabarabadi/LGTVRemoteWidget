import Foundation

/// Client for LG webOS pointer input socket (for navigation buttons)
/// webOS 22/23 require a separate WebSocket connection for arrow keys, OK, etc.
public final class PointerInputClient: NSObject {
    private var task: URLSessionWebSocketTask?
    private let queue = DispatchQueue(label: "com.lgtv.pointerinput", qos: .userInitiated)
    private var isConnected = false
    
    public override init() {
        super.init()
    }
    
    /// Connect to the pointer input socket using the socketPath from getPointerInputSocket
    public func connect(socketPath: String) async throws {
        print("[PointerInput] 🔌 Connecting to pointer socket: \(socketPath)")
        
        guard let url = URL(string: socketPath) else {
            print("[PointerInput] ❌ Invalid socket path URL")
            throw PointerInputError.invalidSocketPath
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let newTask = session.webSocketTask(with: request)
        
        self.task = newTask
        
        print("[PointerInput] 🚀 Starting WebSocket task...")
        newTask.resume()
        
        // Start receiving messages to keep connection alive
        receiveMessage(task: newTask)
        
        // Give it a moment to connect
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second (increased from 500ms)
        isConnected = true
        
        print("[PointerInput] ✅ Pointer socket connected and ready")
    }
    
    /// Receive messages from the pointer socket (keeps connection alive)
    private func receiveMessage(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("[PointerInput] 📨 Received: \(text)")
                case .data(let data):
                    print("[PointerInput] 📨 Received data: \(data.count) bytes")
                @unknown default:
                    print("[PointerInput] 📨 Received unknown message type")
                }
                // Continue receiving
                self?.receiveMessage(task: task)
            case .failure(let error):
                print("[PointerInput] ❌ Receive error: \(error.localizedDescription)")
                self?.isConnected = false
            }
        }
    }
    
    /// Send a button press (UP, DOWN, LEFT, RIGHT, ENTER, BACK, HOME, etc.)
    public func sendButton(_ button: Button) async throws {
        print("[PointerInput] 🔍 sendButton called - isConnected: \(isConnected), task: \(task != nil ? "exists" : "nil")")
        
        guard isConnected, let task = task else {
            print("[PointerInput] ❌ Cannot send button - not connected! isConnected: \(isConnected), task: \(task != nil)")
            throw PointerInputError.notConnected
        }
        
        // Message format: "type:button\nname:BUTTONNAME\n\n"
        // The double newline at the end is important!
        let message = "type:button\nname:\(button.rawValue)\n\n"
        
        print("[PointerInput] 📤 Sending button: \(button.rawValue)")
        print("[PointerInput] 📝 Message bytes: \(message.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("[PointerInput] 📝 Message length: \(message.count) bytes")
        
        do {
            try await task.send(.string(message))
            print("[PointerInput] ✅ Button sent successfully: \(button.rawValue)")
        } catch {
            print("[PointerInput] ❌ Failed to send button: \(error.localizedDescription)")
            throw PointerInputError.sendFailed(error.localizedDescription)
        }
    }
    
    /// Send a click event
    public func sendClick() async throws {
        guard isConnected, let task = task else {
            throw PointerInputError.notConnected
        }
        
        let message = """
        type:click
        
        """
        
        print("[PointerInput] 📤 Sending click")
        
        try await task.send(.string(message))
    }
    
    /// Disconnect from the pointer socket
    public func disconnect() {
        print("[PointerInput] 🔌 Disconnecting pointer socket")
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
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
        
        public var errorDescription: String? {
            switch self {
            case .notConnected: return "Pointer socket not connected"
            case .invalidSocketPath: return "Invalid pointer socket path"
            case .sendFailed(let msg): return "Failed to send button: \(msg)"
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension PointerInputClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[PointerInput] 🔓 Pointer socket opened")
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[PointerInput] 🔒 Pointer socket closed: \(closeCode.rawValue)")
        isConnected = false
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accept self-signed certificates (same as main WebSocket)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: trust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

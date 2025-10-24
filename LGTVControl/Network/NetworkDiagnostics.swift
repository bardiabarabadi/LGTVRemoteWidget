import Foundation
import Network

public final class NetworkDiagnostics {
    public static func testTCPConnection(host: String, port: UInt16, timeout: TimeInterval = 5.0) async -> (success: Bool, message: String) {
        print("[NetworkDiagnostics] 🔍 Testing TCP connection to \(host):\(port)")
        
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            
            var hasCompleted = false
            
            connection.stateUpdateHandler = { state in
                guard !hasCompleted else { return }
                
                switch state {
                case .ready:
                    print("[NetworkDiagnostics] ✅ TCP connection established to \(host):\(port)")
                    hasCompleted = true
                    connection.cancel()
                    continuation.resume(returning: (true, "TCP connection successful"))
                    
                case .failed(let error):
                    print("[NetworkDiagnostics] ❌ TCP connection failed: \(error)")
                    hasCompleted = true
                    connection.cancel()
                    continuation.resume(returning: (false, "TCP connection failed: \(error.localizedDescription)"))
                    
                case .waiting(let error):
                    print("[NetworkDiagnostics] ⏳ TCP connection waiting: \(error)")
                    
                default:
                    print("[NetworkDiagnostics] 🔄 TCP connection state: \(state)")
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout handler
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard !hasCompleted else { return }
                print("[NetworkDiagnostics] ⏱️ TCP connection timeout after \(timeout) seconds")
                hasCompleted = true
                connection.cancel()
                continuation.resume(returning: (false, "Connection timeout after \(timeout) seconds"))
            }
        }
    }
    
    public static func testHTTPConnection(host: String, port: UInt16) async -> (success: Bool, message: String, statusCode: Int?) {
        print("[NetworkDiagnostics] 🔍 Testing HTTP connection to \(host):\(port)")
        
        guard let url = URL(string: "http://\(host):\(port)/") else {
            return (false, "Invalid URL", nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[NetworkDiagnostics] ✅ HTTP response received - status: \(httpResponse.statusCode)")
                return (true, "HTTP connection successful", httpResponse.statusCode)
            }
            return (false, "Invalid response type", nil)
        } catch {
            print("[NetworkDiagnostics] ❌ HTTP connection failed: \(error)")
            return (false, "HTTP connection failed: \(error.localizedDescription)", nil)
        }
    }
}

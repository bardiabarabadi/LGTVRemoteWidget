import Foundation
import Network

/// Raw WebSocket handshake test to diagnose TV connection issues
public final class RawWebSocketTest {
    
    public static func testRawWebSocketHandshake(host: String, port: UInt16) async -> (success: Bool, response: String) {
        print("[RawWebSocket] 🔍 Testing raw WebSocket handshake to \(host):\(port)")
        
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            
            var receivedData = Data()
            var hasCompleted = false
            
            connection.stateUpdateHandler = { state in
                print("[RawWebSocket] Connection state: \(state)")
                
                switch state {
                case .ready:
                    print("[RawWebSocket] ✅ TCP connection ready, sending WebSocket handshake...")
                    
                    // Send raw WebSocket handshake HTTP request
                    let handshake = """
                    GET / HTTP/1.1\r
                    Host: \(host):\(port)\r
                    Upgrade: websocket\r
                    Connection: Upgrade\r
                    Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
                    Sec-WebSocket-Version: 13\r
                    Origin: http://\(host)\r
                    \r
                    
                    """
                    
                    let data = handshake.data(using: .utf8)!
                    print("[RawWebSocket] Sending handshake (\(data.count) bytes):")
                    print(handshake)
                    
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            print("[RawWebSocket] ❌ Send failed: \(error)")
                            if !hasCompleted {
                                hasCompleted = true
                                connection.cancel()
                                continuation.resume(returning: (false, "Send failed: \(error.localizedDescription)"))
                            }
                        } else {
                            print("[RawWebSocket] ✅ Handshake sent, waiting for response...")
                            
                            // Receive response
                            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                                if let error = error {
                                    print("[RawWebSocket] ❌ Receive failed: \(error)")
                                    if !hasCompleted {
                                        hasCompleted = true
                                        connection.cancel()
                                        continuation.resume(returning: (false, "Receive failed: \(error.localizedDescription)"))
                                    }
                                } else if let data = data {
                                    receivedData.append(data)
                                    let response = String(data: receivedData, encoding: .utf8) ?? "<binary data>"
                                    print("[RawWebSocket] 📥 Received \(data.count) bytes:")
                                    print(response)
                                    
                                    if !hasCompleted {
                                        hasCompleted = true
                                        connection.cancel()
                                        let success = response.contains("101") || response.contains("Switching Protocols")
                                        continuation.resume(returning: (success, response))
                                    }
                                }
                            }
                        }
                    })
                    
                case .failed(let error):
                    print("[RawWebSocket] ❌ Connection failed: \(error)")
                    if !hasCompleted {
                        hasCompleted = true
                        connection.cancel()
                        continuation.resume(returning: (false, "Connection failed: \(error.localizedDescription)"))
                    }
                    
                case .waiting(let error):
                    print("[RawWebSocket] ⏳ Connection waiting: \(error)")
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                if !hasCompleted {
                    print("[RawWebSocket] ⏱️ Timeout after 10 seconds")
                    hasCompleted = true
                    connection.cancel()
                    continuation.resume(returning: (false, "Timeout - no response from TV"))
                }
            }
        }
    }
}

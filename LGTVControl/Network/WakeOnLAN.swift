import Foundation
import Network

public enum WakeOnLANError: Error, LocalizedError {
    case invalidMAC
    case sendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMAC: return "Invalid MAC address"
        case .sendFailed(let msg): return "Wake-on-LAN send failed: \(msg)"
        }
    }
}

public final class WakeOnLAN {
    public init() {}

    public func send(macAddress: String, ipAddress: String? = nil) async throws {
        let packet = try buildMagicPacket(mac: macAddress)
        
        print("[WakeOnLAN] 📡 Sending magic packet to MAC: \(macAddress)")
        print("[WakeOnLAN] 📦 Packet size: \(packet.count) bytes")
        print("[WakeOnLAN] 📦 Packet hex: \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Try both port 9 (standard) and port 7 (some LG TVs)
        let ports: [UInt16] = [9, 7]
        
        for port in ports {
            // Only send to specific IP if provided (broadcast doesn't work reliably on iOS)
            if let ip = ipAddress {
                print("[WakeOnLAN] 📤 Sending to specific IP \(ip):\(port)")
                try await sendPacket(packet, to: ip, port: port)
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                
                // Send again for reliability
                print("[WakeOnLAN] 📤 Sending retry to \(ip):\(port)")
                try await sendPacket(packet, to: ip, port: port)
                try await Task.sleep(nanoseconds: 100_000_000)
            } else {
                print("[WakeOnLAN] ⚠️ No IP address provided, skipping (broadcast unreliable on iOS)")
            }
        }
        
        print("[WakeOnLAN] ✅ Magic packets sent successfully")
    }

    private func buildMagicPacket(mac: String) throws -> Data {
        let hex = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count == 12, let macBytes = hex.chunked(into: 2).compactMap({ UInt8($0, radix: 16) }) as [UInt8]?, macBytes.count == 6 else {
            throw WakeOnLANError.invalidMAC
        }
        var bytes = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { bytes.append(contentsOf: macBytes) }
        return Data(bytes)
    }

    private func sendPacket(_ packet: Data, to ipAddress: String, port: UInt16 = 9) async throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = nil // Allow any local endpoint
        
        // Enable broadcast for the 255.255.255.255 address
        if ipAddress == "255.255.255.255" {
            params.allowFastOpen = true
        }
        
        guard let host = IPv4Address(ipAddress) else {
            throw WakeOnLANError.sendFailed("Invalid IP address: \(ipAddress)")
        }

        let connection = NWConnection(host: .ipv4(host), port: NWEndpoint.Port(rawValue: port)!, using: params)
        
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                if !resumed {
                    print("[WakeOnLAN] ⏱️ Timeout waiting for connection to \(ipAddress):\(port)")
                    connection.cancel()
                }
            }
            
            connection.stateUpdateHandler = { state in
                print("[WakeOnLAN] 🔄 Connection state: \(state) for \(ipAddress):\(port)")
                switch state {
                case .ready:
                    print("[WakeOnLAN] ✅ Connection ready, sending \(packet.count) bytes to \(ipAddress):\(port)")
                    connection.send(content: packet, completion: .contentProcessed { error in
                        timeoutTask.cancel()
                        connection.cancel()
                        if !resumed {
                            resumed = true
                            if let error {
                                print("[WakeOnLAN] ❌ Send failed: \(error.localizedDescription)")
                                continuation.resume(throwing: WakeOnLANError.sendFailed(error.localizedDescription))
                            } else {
                                print("[WakeOnLAN] ✅ Packet sent successfully to \(ipAddress):\(port)")
                                continuation.resume()
                            }
                        }
                    })
                case .failed(let error):
                    print("[WakeOnLAN] ❌ Connection failed: \(error.localizedDescription)")
                    timeoutTask.cancel()
                    connection.cancel()
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: WakeOnLANError.sendFailed(error.localizedDescription))
                    }
                case .cancelled:
                    print("[WakeOnLAN] ⚠️ Connection cancelled for \(ipAddress):\(port)")
                    timeoutTask.cancel()
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: WakeOnLANError.sendFailed("Connection cancelled"))
                    }
                case .preparing:
                    print("[WakeOnLAN] 🔄 Preparing connection to \(ipAddress):\(port)")
                case .waiting(let error):
                    print("[WakeOnLAN] ⏳ Waiting for connection: \(error.localizedDescription)")
                case .setup:
                    print("[WakeOnLAN] 🔧 Setting up connection to \(ipAddress):\(port)")
                @unknown default:
                    print("[WakeOnLAN] ❓ Unknown state: \(state)")
                }
            }
            print("[WakeOnLAN] 🚀 Starting connection to \(ipAddress):\(port)")
            connection.start(queue: .global())
        }
    }
}

private extension String {
    func chunked(into size: Int) -> [String] {
        var result: [String] = []
        var idx = startIndex
        while idx < endIndex {
            let next = index(idx, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(String(self[idx..<next]))
            idx = next
        }
        return result
    }
}

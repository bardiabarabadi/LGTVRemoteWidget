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
        let ports: [UInt16] = [9, 7]
        
        for port in ports {
            if let ip = ipAddress {
                try await sendPacket(packet, to: ip, port: port)
                try await Task.sleep(nanoseconds: 100_000_000)
                try await sendPacket(packet, to: ip, port: port)
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
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
        params.requiredLocalEndpoint = nil
        
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
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !resumed {
                    connection.cancel()
                }
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: packet, completion: .contentProcessed { error in
                        timeoutTask.cancel()
                        connection.cancel()
                        if !resumed {
                            resumed = true
                            if let error {
                                continuation.resume(throwing: WakeOnLANError.sendFailed(error.localizedDescription))
                            } else {
                                continuation.resume()
                            }
                        }
                    })
                case .failed(let error):
                    timeoutTask.cancel()
                    connection.cancel()
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: WakeOnLANError.sendFailed(error.localizedDescription))
                    }
                case .cancelled:
                    timeoutTask.cancel()
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: WakeOnLANError.sendFailed("Connection cancelled"))
                    }
                default:
                    break
                }
            }
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

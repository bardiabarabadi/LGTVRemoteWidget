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

    public func send(macAddress: String) async throws {
        let packet = try buildMagicPacket(mac: macAddress)
        try await sendPacket(packet)
        // Retry a couple more times to increase reliability
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        try await sendPacket(packet)
        try await Task.sleep(nanoseconds: 100_000_000)
        try await sendPacket(packet)
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

    private func sendPacket(_ packet: Data) async throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let connection = NWConnection(host: .ipv4(IPv4Address("255.255.255.255")!), port: 9, using: params)
        let group = DispatchGroup()
        var sendError: Error?
        group.enter()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: packet, completion: .contentProcessed { error in
                    if let error { sendError = error }
                    connection.cancel()
                    group.leave()
                })
            case .failed(let error):
                sendError = error
                connection.cancel()
                group.leave()
            default:
                break
            }
        }
        connection.start(queue: .global())
        group.wait()
        if let sendError { throw WakeOnLANError.sendFailed(sendError.localizedDescription) }
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

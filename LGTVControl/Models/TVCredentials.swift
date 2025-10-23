import Foundation

public struct TVCredentials: Codable, Equatable {
    public var ipAddress: String
    public var macAddress: String
    public var clientKey: String?

    public init(ipAddress: String, macAddress: String, clientKey: String? = nil) {
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.clientKey = clientKey
    }
}

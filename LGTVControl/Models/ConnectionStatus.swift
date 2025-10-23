import Foundation

public enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case pairingRequired(code: String?)
    case error(String)
}

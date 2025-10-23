import Foundation
import Security

public enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): return "Keychain error: \(status)"
        case .encodingFailed: return "Failed to encode/decode data"
        }
    }
}

public final class KeychainManager {
    public init() {}

    public func save<T: Codable>(_ object: T, service: String, account: String) throws {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(object) else { throw KeychainError.encodingFailed }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    public func load<T: Codable>(_ type: T.Type, service: String, account: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unexpectedStatus(status)
        }
        let decoder = JSONDecoder()
        guard let object = try? decoder.decode(type, from: data) else { throw KeychainError.encodingFailed }
        return object
    }

    public func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
    }
}

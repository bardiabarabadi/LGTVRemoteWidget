import Foundation

// Lightweight AnyCodable to support arbitrary JSON payloads
public struct AnyCodable: Codable, Equatable {
    public let value: Any
    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = Optional<Any>.none as Any
        } else if let b = try? container.decode(Bool.self) {
            self.value = b
        } else if let i = try? container.decode(Int.self) {
            self.value = i
        } else if let d = try? container.decode(Double.self) {
            self.value = d
        } else if let s = try? container.decode(String.self) {
            self.value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            self.value = arr.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = v.value }
            self.value = result
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case Optional<Any>.none:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let arr as [Any]:
            try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported JSON type")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

extension AnyCodable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        areEqual(lhs.value, rhs.value)
    }

    private static func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if isNil(lhs), isNil(rhs) { return true }

        switch (lhs, rhs) {
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Int, r as Double):
            return Double(l) == r
        case let (l as Double, r as Int):
            return l == Double(r)
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        case let (l as [Any], r as [Any]):
            guard l.count == r.count else { return false }
            return zip(l, r).allSatisfy { areEqual($0, $1) }
        case let (l as [String: Any], r as [String: Any]):
            guard l.count == r.count else { return false }
            for (key, lValue) in l {
                guard let rValue = r[key], areEqual(lValue, rValue) else { return false }
            }
            return true
        case let (l as NSNumber, r as NSNumber):
            return l == r
        default:
            return false
        }
    }

    private static func isNil(_ value: Any) -> Bool {
        if value is NSNull { return true }
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }
}

public enum SSAPRequestType: String, Codable {
    case register
    case request
}

public struct SSAPRequest: Codable, Equatable {
    public var type: SSAPRequestType
    public var id: String
    public var uri: String?
    public var payload: [String: AnyCodable]?

    public init(type: SSAPRequestType, id: String = UUID().uuidString, uri: String? = nil, payload: [String: AnyCodable]? = nil) {
        self.type = type
        self.id = id
        self.uri = uri
        self.payload = payload
    }
}

public struct SSAPResponse: Codable, Equatable {
    public var type: String? // e.g., "response", "registered", "error"
    public var id: String?
    public var payload: [String: AnyCodable]?
    public var error: String?
    public var returnValue: Bool?
}

public struct SSAPManifest: Codable, Equatable {
    public var manifestVersion: Int
    public var appId: String
    public var appName: String
    public var vendorName: String
    public var version: String
    public var permissions: [String]
    public var signatures: [Signature]
    public var localizedAppNames: [String: String]
    public var localizedVendorNames: [String: String]
    public var categories: [String]
    public var devices: [String]

    public struct Signature: Codable, Equatable {
        public var signatureVersion: Int
        public var signature: String

        public init(signatureVersion: Int, signature: String) {
            self.signatureVersion = signatureVersion
            self.signature = signature
        }
    }

    public init(
        manifestVersion: Int = 1,
        appId: String,
        appName: String,
        vendorName: String,
        version: String,
        permissions: [String],
        signatures: [Signature],
        localizedAppNames: [String: String],
        localizedVendorNames: [String: String],
        categories: [String],
        devices: [String]
    ) {
        self.manifestVersion = manifestVersion
        self.appId = appId
        self.appName = appName
        self.vendorName = vendorName
        self.version = version
        self.permissions = permissions
        self.signatures = signatures
        self.localizedAppNames = localizedAppNames
        self.localizedVendorNames = localizedVendorNames
        self.categories = categories
        self.devices = devices
    }
}

public struct SSAPRegisterPayload: Codable, Equatable {
    public var forcePairing: Bool
    public var pairingType: String
    public var manifest: SSAPManifest
    public var clientKey: String?
    public var pin: String?

    public init(
        forcePairing: Bool = false,
        pairingType: String = "PROMPT",
        manifest: SSAPManifest,
        clientKey: String? = nil,
        pin: String? = nil
    ) {
        self.forcePairing = forcePairing
        self.pairingType = pairingType
        self.manifest = manifest
        self.clientKey = clientKey
        self.pin = pin
    }

    enum CodingKeys: String, CodingKey {
        case forcePairing
        case pairingType
        case manifest
        case clientKey = "client-key"
        case pin
    }
}

public struct SSAPRegisterRequest: Codable, Equatable {
    public var type: SSAPRequestType = .register
    public var id: String
    public var payload: SSAPRegisterPayload

    public init(id: String = UUID().uuidString, payload: SSAPRegisterPayload) {
        self.id = id
        self.payload = payload
    }
}

public enum SSAPRegistrationResult: Equatable {
    case success(clientKey: String)
    case pairingRequired(code: String?)
}

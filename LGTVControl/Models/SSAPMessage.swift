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

public struct SSAPRequest: Codable, Equatable {
    public var type: String // "register" or "request"
    public var id: String
    public var uri: String
    public var payload: [String: AnyCodable]?

    public init(type: String, id: String = UUID().uuidString, uri: String, payload: [String: AnyCodable]? = nil) {
        self.type = type
        self.id = id
        self.uri = uri
        self.payload = payload
    }
}

public struct SSAPResponse: Codable, Equatable {
    public var type: String? // e.g., "response", "registered"
    public var id: String?
    public var payload: [String: AnyCodable]?
    public var error: String?
}

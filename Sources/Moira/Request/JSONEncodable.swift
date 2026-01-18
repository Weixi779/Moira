import Foundation

/// Provides JSON encoding for request bodies.
public protocol JSONEncodable: Sendable {
    /// Encodes the value using the given `JSONEncoder`.
    func encode(using encoder: JSONEncoder) throws -> Data
}

/// Type-erased wrapper for `Encodable` values.
public struct AnyJSONEncodable<T: Encodable & Sendable>: JSONEncodable {
    private let value: T

    public init(_ value: T) {
        self.value = value
    }

    public func encode(using encoder: JSONEncoder) throws -> Data {
        try encoder.encode(value)
    }
}

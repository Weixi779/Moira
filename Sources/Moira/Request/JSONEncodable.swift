import Foundation

public protocol JSONEncodable: Sendable {
    func encode(using encoder: JSONEncoder) throws -> Data
}

public struct AnyJSONEncodable<T: Encodable & Sendable>: JSONEncodable {
    private let value: T

    public init(_ value: T) {
        self.value = value
    }

    public func encode(using encoder: JSONEncoder) throws -> Data {
        try encoder.encode(value)
    }
}

import Foundation

/// Decodes response data into typed models.
public protocol ResponseDecoder: Sendable {
    /// Decodes the given data into the requested type.
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: ResponseDecoder {}

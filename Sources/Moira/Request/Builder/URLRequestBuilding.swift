import Foundation

/// Strategy for building `URLRequest` values from `APIRequest` definitions.
public protocol URLRequestBuilding: Sendable {
    /// Builds a `URLRequest` for the provided API target.
    func build(_ target: any APIRequest) throws -> URLRequest
}

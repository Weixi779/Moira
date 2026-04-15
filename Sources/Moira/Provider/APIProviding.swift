import Foundation

/// Core request interface for executing API requests.
public protocol APIRequesting: Sendable {
    /// Executes a request and returns the raw response.
    @discardableResult
    func request(_ target: any APIRequest) async throws -> APIResponse
    /// Executes a request and decodes the response body.
    func request<T: Decodable>(_ target: any APIRequest) async throws -> T
}

/// High-level request interface used by application code.
public protocol APIProviding: APIRequesting {}

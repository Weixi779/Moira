import Foundation

/// Transforms requests before transport.
public protocol TransformPlugin: RequestPlugin {
    /// Runs before building a `URLRequest` to alter the target request.
    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest
    /// Runs after building a `URLRequest` to adjust headers, timeouts, etc.
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest
}

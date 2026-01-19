import Foundation

/// Transforms requests or responses in the pipeline.
public protocol TransformPlugin: RequestPlugin {
    /// Runs before building a `URLRequest` to alter the target request.
    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest
    /// Runs after building a `URLRequest` to adjust headers, timeouts, etc.
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest
    /// Runs after the client returns to transform the raw response.
    func processResponse(_ response: APIResponse) async throws -> APIResponse
}

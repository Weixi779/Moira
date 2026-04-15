import Foundation

/// Execution layer that performs requests and returns responses or tasks.
public protocol APIClient {
    /// Executes a simple request and returns the raw response.
    func request(_ request: URLRequest) async throws -> APIResponse
}

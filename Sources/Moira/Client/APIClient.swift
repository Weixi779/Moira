import Foundation

/// Execution layer that performs requests and returns responses or tasks.
public protocol APIClient {
    /// Executes a simple request and returns the raw response.
    func request(_ request: URLRequest) async throws -> APIResponse
    /// Starts an upload and returns a task with progress.
    func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse>
}

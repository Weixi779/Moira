import Foundation

/// Execution layer that performs requests and returns responses.
public protocol APIClient: Sendable {
    /// Executes a simple request and returns the raw response.
    func request(_ request: URLRequest) async throws -> APIResponse
}

/// Optional execution capability for uploads.
public protocol APIUploadClient: Sendable {
    /// Starts an upload and returns a task with progress.
    func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse>
}

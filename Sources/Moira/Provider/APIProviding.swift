import Foundation

/// Core request interface for executing API requests.
public protocol APIRequesting: Sendable {
    /// Executes a request and returns the raw response.
    @discardableResult
    func request(_ target: any APIRequest) async throws -> APIResponse
    /// Executes a request and decodes the response body.
    func request<T: Decodable>(_ target: any APIRequest) async throws -> T
}

/// Upload interface returning tasks with progress support.
public protocol APIUploading: Sendable {
    /// Returns an upload task with progress for the raw response.
    func uploadTask(_ target: any APIRequest) async throws -> UploadTask<APIResponse>
    /// Returns an upload task with progress that decodes the response body.
    func uploadTask<T: Decodable & Sendable>(_ target: any APIRequest) async throws -> UploadTask<T>
}

/// High-level request interface used by application code.
public protocol APIProviding: APIRequesting, APIUploading {}

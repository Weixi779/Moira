import Foundation

/// Upload interface returning tasks with progress support.
public protocol APIUploading: Sendable {
    /// Returns an upload task with progress for the raw response.
    func uploadTask(_ target: any APIRequest) async throws -> UploadTask<APIResponse>
    /// Returns an upload task with progress that decodes the response body.
    func uploadTask<T: Decodable & Sendable>(_ target: any APIRequest) async throws -> UploadTask<T>
}

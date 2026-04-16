import Foundation

/// Represents an upload that can yield progress and a response later.
public final class UploadTask<T: Sendable>: Sendable {
    /// Stream of upload progress updates.
    public let progress: AsyncStream<UploadProgress>
    /// Closure to fetch the response when awaited.
    public let response: @Sendable () async throws -> T

    public init(
        progress: AsyncStream<UploadProgress>,
        response: @escaping @Sendable () async throws -> T
    ) {
        self.progress = progress
        self.response = response
    }
}

import Foundation

/// Represents a request that can yield progress and a response later.
public final class RequestTask<T: Sendable>: Sendable {
    /// Stream of upload/download progress updates.
    public let progress: AsyncStream<RequestProgress>?
    /// Closure to fetch the response when awaited.
    public let response: @Sendable () async throws -> T

    public init(
        progress: AsyncStream<RequestProgress>? = nil,
        response: @escaping @Sendable () async throws -> T
    ) {
        self.progress = progress
        self.response = response
    }
}

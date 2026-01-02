import Foundation

public final class RequestTask: Sendable {
    public let progress: AsyncStream<RequestProgress>?
    public let response: @Sendable () async throws -> APIResponse

    public init(
        progress: AsyncStream<RequestProgress>? = nil,
        response: @escaping @Sendable () async throws -> APIResponse
    ) {
        self.progress = progress
        self.response = response
    }
}

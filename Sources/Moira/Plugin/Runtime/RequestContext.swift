import Foundation

/// Request-scoped state shared across the plugin pipeline.
public actor RequestContext {
    /// Whether the request is a regular request or an upload.
    public enum ExecutionKind: Sendable, Equatable {
        case request
        case upload
    }

    /// Unique identifier for the request.
    public let id: UUID
    /// Original API request target.
    public let target: any APIRequest
    /// Execution kind derived from the target.
    public let executionKind: ExecutionKind
    /// Timestamp when the request started.
    public private(set) var startTime: Date

    /// The built request, once available.
    public private(set) var request: URLRequest?
    /// The latest response, once available.
    public private(set) var response: APIResponse?
    /// The latest error, if one occurred.
    public private(set) var error: Error?
    /// Number of retry attempts made.
    public private(set) var retryCount: Int

    public init(target: any APIRequest) {
        self.id = UUID()
        self.target = target
        if case .upload = target.execution {
            self.executionKind = .upload
        } else {
            self.executionKind = .request
        }
        self.startTime = Date()
        self.retryCount = 0
    }

    public func updateRequest(_ request: URLRequest) {
        self.request = request
    }

    /// Stores the response after client execution.
    public func updateResponse(_ response: APIResponse) {
        self.response = response
    }

    /// Stores the error after a failure.
    public func updateError(_ error: Error) {
        self.error = error
    }

    /// Increments the retry attempt counter.
    public func incrementRetryCount() {
        retryCount += 1
    }

    /// Resets transient state for a retry attempt.
    public func resetForRetry(request: URLRequest) {
        startTime = Date()
        self.request = request
        response = nil
        error = nil
    }

    /// Returns a read-only snapshot for plugins.
    public func snapshot() -> Snapshot {
        Snapshot(
            id: id,
            target: target,
            executionKind: executionKind,
            startTime: startTime,
            request: request,
            response: response,
            error: error,
            retryCount: retryCount
        )
    }

    /// Immutable request context snapshot.
    public struct Snapshot: @unchecked Sendable {
        /// Snapshot identifier matching the request.
        public let id: UUID
        /// Original API request target.
        public let target: any APIRequest
        /// Execution kind derived from the target.
        public let executionKind: ExecutionKind
        /// Timestamp when the request started.
        public let startTime: Date
        /// Built request if available.
        public let request: URLRequest?
        /// Response if available.
        public let response: APIResponse?
        /// Error if available.
        public let error: Error?
        /// Retry count at snapshot time.
        public let retryCount: Int
    }
}

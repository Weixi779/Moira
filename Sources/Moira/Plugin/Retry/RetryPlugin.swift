import Foundation

/// Retry decisions emitted by retry plugins.
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry
    case retryAfter(TimeInterval)
}

/// Defines how retry attempts build a request.
public enum RetryPolicy: Sendable {
    case reuseRequest
    case rebuildRequest
}

/// Defines retry behavior for failed requests.
public protocol RetryPlugin: Sendable {
    /// Policy for rebuilding or reusing requests on retry.
    var policy: RetryPolicy { get }
    /// Decides whether to retry after a failure.
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    /// Called before a retry attempt is made.
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}

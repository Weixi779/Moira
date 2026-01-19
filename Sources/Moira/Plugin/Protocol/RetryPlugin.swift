import Foundation

/// Retry decisions emitted by retry plugins.
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry
    case retryAfter(TimeInterval)
}

/// Defines retry behavior for failed requests.
public protocol RetryPlugin: RequestPlugin {
    /// Decides whether to retry after a failure.
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    /// Called before a retry attempt is made.
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}

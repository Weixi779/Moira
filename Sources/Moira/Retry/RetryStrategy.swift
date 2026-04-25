import Foundation

/// Retry decisions emitted by retry strategies.
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry(RetryRequestBehavior)
    case retryAfter(TimeInterval, RetryRequestBehavior)
}

/// Defines how the next retry attempt obtains its URLRequest.
public enum RetryRequestBehavior: Sendable {
    case reuseRequest
    case rebuildRequest
}

/// Defines retry behavior for transport and raw response processing failures.
public protocol RetryStrategy: Sendable {
    /// Decides whether to retry after a failure.
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    /// Called before a retry attempt is made.
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}

public extension RetryStrategy {
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async {}
}

/// Default strategy that disables retry.
public struct NoRetryStrategy: RetryStrategy {
    public init() {}

    public func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        .doNotRetry
    }
}

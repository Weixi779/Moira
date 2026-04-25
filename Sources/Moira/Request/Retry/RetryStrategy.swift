/// Defines retry behavior for transport and raw response processing failures.
public protocol RetryStrategy: Sendable {
    /// Decides whether to retry after a failure.
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    /// Called before a retry attempt is made.
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}

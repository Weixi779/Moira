/// Defines retry behavior for transport and raw response validation failures.
public protocol RetryStrategy: Sendable {
    /// Decides whether to retry after a failure.
    func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision
    /// Called before a retry attempt is made.
    func willRetry(snapshot: RequestSnapshot, error: Error, decision: RetryDecision) async
}

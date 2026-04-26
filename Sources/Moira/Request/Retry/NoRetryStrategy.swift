/// Default strategy that disables retry.
public struct NoRetryStrategy: RetryStrategy {
    public init() {}

    public func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision {
        .doNotRetry
    }

    public func willRetry(snapshot: RequestSnapshot, error: Error, decision: RetryDecision) async {}
}

/// Default strategy that disables retry.
public struct NoRetryStrategy: RetryStrategy {
    public init() {}

    public func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        .doNotRetry
    }

    public func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async {}
}

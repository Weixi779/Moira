import Foundation

public enum RetryDecision: Sendable {
    case doNotRetry
    case retry
    case retryAfter(TimeInterval)
}

public protocol RetryPlugin: RequestPlugin {
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}

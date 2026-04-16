import Foundation

/// Short-circuit decisions emitted by plugins.
public enum ShortCircuitDecision: Sendable {
    case miss
    case hitResult(APIResponse, source: String? = nil)
    case hitError(Error, source: String? = nil)
}

/// Provides cached or mock responses before executing the client.
public protocol ShortCircuitPlugin: RequestPlugin {
    /// Evaluates whether to return a result or error before execution.
    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision
}

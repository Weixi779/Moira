import Foundation

public enum ShortCircuitDecision: Sendable {
    case miss
    case hitResult(APIResponse, source: String? = nil)
    case hitError(Error, source: String? = nil)
}

public protocol ShortCircuitPlugin: RequestPlugin {
    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision
}

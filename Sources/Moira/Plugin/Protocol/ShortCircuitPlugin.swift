import Foundation

public enum ShortCircuitDecision: Sendable {
    case miss
    case hitResult(RawResponse, source: String? = nil)
    case hitError(Error, source: String? = nil)
}

public protocol ShortCircuitPlugin: PluginType {
    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision
}

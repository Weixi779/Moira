/// Observes request lifecycle events without mutation.
public protocol ObserverPlugin: RequestPlugin {
    /// Called after the request is prepared and before execution.
    func willSend(snapshot: RequestContext.Snapshot) async
    /// Called after a successful response is processed.
    func didReceive(snapshot: RequestContext.Snapshot) async
    /// Called after a failure is finalized.
    func didFail(snapshot: RequestContext.Snapshot) async
}

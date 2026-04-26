/// Observes request lifecycle events without mutation.
public protocol ObserverPlugin: RequestPlugin {
    /// Called immediately before a prepared request is handed to transport.
    func willSend(snapshot: RequestSnapshot) async
    /// Called after a successful response is processed.
    func didReceive(snapshot: RequestSnapshot) async
    /// Called after a failure is finalized.
    func didFail(snapshot: RequestSnapshot) async
}

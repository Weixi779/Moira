/// Observes request lifecycle events without mutation.
public protocol ObserverPlugin: RequestPlugin {
    /// Called before a prepared request is handed to transport for an attempt.
    func willSend(snapshot: RequestSnapshot) async
    /// Called after transport succeeds and raw response validation passes.
    ///
    /// Typed response decoding happens after this hook.
    func didReceive(snapshot: RequestSnapshot) async
    /// Called when a transport, upload, or raw validation failure is finalized
    /// without retry.
    func didFail(snapshot: RequestSnapshot) async
}

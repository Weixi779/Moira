# Plugins

Moira splits plugins into two roles so behavior stays composable. `RequestPlugin` is the marker protocol used by the provider to collect and run transform and observer plugins. Retry is configured separately as a provider strategy.

## TransformPlugin

Use for mutating requests or responses.

```swift
public protocol TransformPlugin: RequestPlugin {
    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest
    func processResponse(_ response: APIResponse) async throws -> APIResponse
}
```

Typical use:
- Inject auth headers
- Normalize paths or parameters
- Transform response payloads

## ObserverPlugin

Use for logging or metrics. Observers never mutate.

```swift
public protocol ObserverPlugin: RequestPlugin {
    func willSend(snapshot: RequestContext.Snapshot) async
    func didReceive(snapshot: RequestContext.Snapshot) async
    func didFail(snapshot: RequestContext.Snapshot) async
}
```

## RetryStrategy

Use for retry decisions after transport or raw response processing failures.

```swift
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry(RetryRequestBehavior)
    case retryAfter(TimeInterval, RetryRequestBehavior)
}

public enum RetryRequestBehavior: Sendable {
    case reuseRequest
    case rebuildRequest
}

public protocol RetryStrategy: Sendable {
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}
```

Retry strategies are passed via `APIProvider(retryStrategy:)`. If omitted, `NoRetryStrategy` disables retry. Request preparation, building, adaptation, and typed decoding failures are not retried. Each retry decision chooses whether the next attempt reuses the current `URLRequest` or rebuilds it.

## Execution behavior

- Transform: runs in order, sequential.
- Observer: runs concurrently.
- Retry: provider strategy decides when to retry and whether to rebuild requests.

## RequestContext

`RequestContext` carries request-scoped state and exposes a read-only snapshot for plugins. Snapshots are immutable and safe to use across concurrent observers.

```swift
public actor RequestContext {
    public let id: UUID
    public let target: any APIRequest
    public private(set) var startTime: Date

    public private(set) var request: URLRequest?
    public private(set) var response: APIResponse?
    public private(set) var error: Error?
    public private(set) var retryCount: Int
}
```

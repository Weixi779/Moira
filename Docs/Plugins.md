# Plugins

Moira splits plugins into three roles so behavior stays composable. `RequestPlugin` is the marker protocol used by the provider to collect and run transform, response validation, and observer plugins. Retry is configured separately as a provider strategy.

## TransformPlugin

Use for mutating requests before transport.

```swift
public protocol TransformPlugin: RequestPlugin {
    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest
}
```

Typical use:
- Inject auth headers
- Normalize paths or parameters

## ResponseValidationPlugin

Use for global raw response validation. Validation plugins inspect `APIResponse`, throw when the response is not acceptable, and never modify the response or perform typed decoding.

```swift
public protocol ResponseValidationPlugin: RequestPlugin {
    func validateResponse(_ response: APIResponse) async throws
}
```

Typical use:
- Enforce accepted status code ranges
- Reject responses with missing required headers
- Gate raw responses before typed decoding

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

Use for retry decisions after transport or raw response validation failures.

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

Retry strategies are passed via `APIProvider(retryStrategy:)`. If omitted, `NoRetryStrategy` disables retry. Request preparation, building, adaptation, upload response validation, and typed decoding failures are not retried. Each retry decision chooses whether the next attempt reuses the current `URLRequest` or rebuilds it.

## Execution behavior

- Transform: runs in order, sequential.
- Response validation: runs in order, sequential, and stops at the first thrown error.
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

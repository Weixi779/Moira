# Plugins

Moira splits plugins into four roles so behavior stays composable.

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

## RetryPlugin

Use for retry decisions.

```swift
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry
    case retryAfter(TimeInterval)
}

public protocol RetryPlugin: RequestPlugin {
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}
```

## ShortCircuitPlugin

Use for cache, mock, or prebuilt responses.

```swift
public enum ShortCircuitDecision: Sendable {
    case miss
    case hitResult(APIResponse, source: String? = nil)
    case hitError(Error, source: String? = nil)
}

public protocol ShortCircuitPlugin: RequestPlugin {
    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision
}
```

## Execution behavior

- Transform: runs in order, sequential.
- Observer: runs concurrently.
- Retry: first non-`doNotRetry` wins.
- ShortCircuit: first hit wins.

## RequestContext

`RequestContext` carries request-scoped state and exposes a read-only snapshot.

```swift
public actor RequestContext {
    public let id: UUID
    public let target: any APIRequest
    public let startTime: Date

    public private(set) var request: URLRequest?
    public private(set) var response: APIResponse?
    public private(set) var error: Error?
    public private(set) var retryCount: Int
}
```

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
    func willSend(snapshot: RequestSnapshot) async
    func didReceive(snapshot: RequestSnapshot) async
    func didFail(snapshot: RequestSnapshot) async
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
    func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestSnapshot, error: Error, decision: RetryDecision) async
}
```

Retry strategies are passed via `APIProvider(retryStrategy:)`. If omitted, `NoRetryStrategy` disables retry. Initial request preparation, building, adaptation, upload response validation, and typed decoding failures are not retried. Each retry decision chooses whether the next attempt reuses the current `URLRequest` or rebuilds it.

## Execution behavior

- Transform: runs in order, sequential.
- Response validation: runs in order, sequential, and stops at the first thrown error.
- Observer: runs concurrently.
- `willSend`: runs only when a prepared request is about to be handed to transport.
- Retry: provider strategy decides when to retry and whether to rebuild requests.

## RequestSnapshot

`RequestSnapshot` is the public read-only lifecycle model for observers and retry strategies. Its `target` is always the original target before transform plugins. `executionKind` is resolved from the prepared target that will actually be dispatched.

```swift
public enum RequestExecutionKind: Sendable, Equatable {
    case request
    case upload
}

public struct RequestSnapshot: @unchecked Sendable {
    public let id: UUID
    public let target: any APIRequest
    public let executionKind: RequestExecutionKind
    public let attemptStartedAt: Date
    public let request: URLRequest?
    public let response: APIResponse?
    public let error: Error?
    public let retryCount: Int
}
```

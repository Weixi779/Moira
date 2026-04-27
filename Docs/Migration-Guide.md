# Migration Guide to v1.9.0

This guide covers the practical migration path from the pre-1.0 API line,
especially `v0.4.x`, to `v1.9.0`.

`v1.9.0` is the first stable public release of Moira. It follows the internal
stabilization series ending at `internal/v1.8.0` and establishes the public 1.x
API baseline.

## Package Products

Core usage imports `Moira`:

```swift
import Moira
```

Alamofire-backed transport now lives in a separate product:

```swift
import Moira
import MoiraAlamofire

let provider = APIProvider(
    client: AlamofireClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)
```

If you do not need Alamofire-specific transport behavior, use the Foundation-only
client shipped by `Moira`:

```swift
let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)
```

## APIRequest

Every `APIRequest` conformer must now declare how it executes:

```swift
var execution: RequestExecution { .request }
```

Uploads use the same request model with an upload execution:

```swift
struct UploadAvatarRequest: APIRequest {
    let path = "/avatar"
    let method: RequestMethod = .post
    let payload = RequestPayload()
    let execution: RequestExecution

    init(data: Data) {
        execution = .upload(.data(data))
    }
}
```

## Request Building

`RequestBuilder` has been replaced by `URLRequestBuilder`.

```swift
let builder = URLRequestBuilder(baseURL: baseURL)
let provider = APIProvider(client: URLSessionClient(), builder: builder)
```

For custom construction rules, conform to `URLRequestBuilding`.

## RequestPayload

`RequestPayload` now favors static factories and chaining.

```swift
let payload = RequestPayload.query("page", "1")
    .query("sort", "name")

let body = RequestPayload.json(CreateUser(name: "Moira"))
```

Body helpers replace the current body when chained; query helpers append query
items.

## Uploads

Transport capabilities are split:

- `APIClient` executes regular requests.
- `APIUploadClient` executes uploads.

`APIProvider.uploadTask(_:)` requires the configured client to also conform to
`APIUploadClient`. Otherwise it throws `APIError.capabilityNotSupported`.

```swift
let task = try await provider.uploadTask(UploadAvatarRequest(data: imageData))

for await progress in task.progress {
    print(progress.completedBytes)
}

let response = try await task.response()
```

Upload responses run raw response validation, but uploads are not retried by the
default request retry flow.

## Plugins

Plugins now have narrower roles:

- `TransformPlugin` mutates requests through `prepareRequest(_:)` and
  `adaptRequest(_:)`.
- `ResponseValidationPlugin` validates raw `APIResponse` values.
- `ObserverPlugin` observes lifecycle snapshots without mutation.

Retry is no longer a plugin. Configure it on the provider:

```swift
let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: baseURL),
    retryStrategy: MyRetryStrategy()
)
```

## Retry

`RetryStrategy` decides whether a transport or raw response validation failure
should retry:

```swift
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry(RetryRequestBehavior)
    case retryAfter(TimeInterval, RetryRequestBehavior)
}
```

Each decision chooses whether the next attempt reuses the current `URLRequest`
or rebuilds it.

Failures during request preparation, request building, request adaptation,
typed decoding, and upload validation do not enter the regular retry flow.

## Removed Short-Circuit and Stub Hooks

`ShortCircuitPlugin` was removed. Provider-level stubbing and short-circuiting
are intentionally not part of the v1.9.0 API.

For business tests, prefer mocking at your service boundary:

```swift
protocol UserServicing: Sendable {
    func profile(id: String) async throws -> User
}
```

Then inject a mock service in application tests instead of building raw HTTP
responses at the provider layer.

## Error Handling

Moira no longer wraps every unknown error in `APIError.underlying`.

- Moira-defined failures still use `APIError`.
- First-party clients wrap transport failures as `APIError.underlying` when
  useful response details are available.
- Custom clients, plugins, and validation code may propagate their own errors
  unchanged.

Callers should not assume every provider failure is an `APIError`.

# Clients

Clients are the transport execution layer.
`APIClient` is the baseline request capability, while `APIUploadClient` is the optional upload capability.

`Moira` ships the Foundation-only `URLSessionClient`. `MoiraAlamofire` is a separate product that provides `AlamofireClient`.

## APIClient

```swift
public protocol APIClient: Sendable {
    func request(_ request: URLRequest) async throws -> APIResponse
}
```

## APIUploadClient

```swift
public protocol APIUploadClient: Sendable {
    func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse>
}
```

## AlamofireClient

`AlamofireClient` adapts Alamofire to both `APIClient` and `APIUploadClient`.
When you need stable extended transport capabilities beyond the core URLSession path, such as richer upload behavior or Alamofire's mature request lifecycle features, prefer the Alamofire-backed implementation or provide your own `APIClient` / `APIUploadClient` implementation.

```swift
import Moira
import MoiraAlamofire

let provider = APIProvider(
    client: AlamofireClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)
```

## URLSessionClient

`URLSessionClient` adapts URLSession to both `APIClient` and `APIUploadClient`.

Behavior notes:
- Headers are normalized into `[String: String]` for inspection.
- Upload exposes progress via `AsyncStream<UploadProgress>`.
- First-party clients wrap transport failures as `APIError.underlying`, with the `APIResponse` attached when available.
- Custom `APIClient` implementations may throw their own errors; `APIProvider` does not wrap unknown client errors.
- `APIProvider.uploadTask` requires an upload-capable client. If the configured client does not conform to `APIUploadClient`, it throws `APIError.capabilityNotSupported`.

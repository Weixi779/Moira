# Clients

`APIClient` is the execution layer.
It stays close to native networking APIs and returns `APIResponse` for regular requests or `UploadTask<APIResponse>` for uploads.

## APIClient

```swift
public protocol APIClient {
    func request(_ request: URLRequest) async throws -> APIResponse
    func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse>
}
```

## AlamofireClient

`AlamofireClient` adapts Alamofire to `APIClient`.

Behavior notes:
- Headers are normalized into `[String: String]` for inspection.
- Upload exposes progress via `AsyncStream<UploadProgress>`.
- Errors from Alamofire are wrapped as `APIError.underlying`, with the `APIResponse` attached when available.
- Custom `APIClient` implementations may throw their own errors; `APIProvider` does not wrap unknown client errors.

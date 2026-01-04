# Clients

`APIClient` is the execution layer.
It returns `APIResponse` or `RequestTask` for uploads/downloads.

## APIClient

```swift
public protocol APIClient {
    func request(_ request: URLRequest) async throws -> APIResponse
    func upload(_ request: URLRequest, source: UploadSource) throws -> RequestTask
    func download(_ request: URLRequest) throws -> RequestTask
}
```

## AlamofireClient

`AlamofireClient` adapts Alamofire to `APIClient`.

Behavior notes:
- Headers are normalized into `[String: String]` for inspection.
- Upload and download expose progress via `AsyncStream<RequestProgress>`.
- Errors from Alamofire are wrapped as `APIError.underlying` by the provider.

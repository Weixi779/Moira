# Client 适配

`APIClient` 是执行层，负责发起请求并返回 `APIResponse` 或 `RequestTask`。

## APIClient

```swift
public protocol APIClient {
    func request(_ request: URLRequest) async throws -> APIResponse
    func upload(_ request: URLRequest, source: UploadSource) throws -> RequestTask
    func download(_ request: URLRequest) throws -> RequestTask
}
```

## AlamofireClient

`AlamofireClient` 将 Alamofire 适配到 `APIClient`。

行为说明：
- response headers 会被归一化为 `[String: String]` 便于查看。
- 上传/下载通过 `AsyncStream<RequestProgress>` 暴露进度。
- 具体错误由 Provider 统一映射为 `APIError.underlying`。

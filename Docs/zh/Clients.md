# Client 适配

`APIClient` 是执行层，尽量贴近原生网络 API，负责发起请求并返回 `APIResponse` 或 `RequestTask<APIResponse>`。

## APIClient

```swift
public protocol APIClient {
    func request(_ request: URLRequest) async throws -> APIResponse
    func upload(_ request: URLRequest, source: UploadSource) throws -> RequestTask<APIResponse>
    func download(_ request: URLRequest) throws -> RequestTask<APIResponse>
}
```

## AlamofireClient

`AlamofireClient` 将 Alamofire 适配到 `APIClient`。

行为说明：
- response headers 会被归一化为 `[String: String]` 便于查看。
- 上传/下载通过 `AsyncStream<RequestProgress>` 暴露进度。
- 具体错误会被包装为 `APIError.underlying`，并在可用时附带 `APIResponse`。

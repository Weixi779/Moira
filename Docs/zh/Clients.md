# Client 适配

`APIClient` 是执行层，尽量贴近原生网络 API，负责发起请求并返回 `APIResponse` 或 `UploadTask<APIResponse>`。

## APIClient

```swift
public protocol APIClient {
    func request(_ request: URLRequest) async throws -> APIResponse
    func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse>
}
```

## AlamofireClient

`AlamofireClient` 将 Alamofire 适配到 `APIClient`。

行为说明：
- response headers 会被归一化为 `[String: String]` 便于查看。
- 上传通过 `AsyncStream<UploadProgress>` 暴露进度。
- Alamofire 错误会被包装为 `APIError.underlying`，并在可用时附带 `APIResponse`。
- 自定义 `APIClient` 可以抛出自己的错误；`APIProvider` 不会包装未知 client 错误。

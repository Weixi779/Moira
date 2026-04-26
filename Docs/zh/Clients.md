# Client 适配

Client 是传输执行层。
`APIClient` 是基础请求能力，`APIUploadClient` 是可选上传能力。

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

`AlamofireClient` 将 Alamofire 同时适配到 `APIClient` 和 `APIUploadClient`。
如果需要核心 URLSession 路径之外更稳定成熟的传输层扩展能力，例如更完整的上传行为或 Alamofire 成熟的请求生命周期能力，优先使用 Alamofire-backed 实现，或者提供自己的 `APIClient` / `APIUploadClient` 实现。

## URLSessionClient

`URLSessionClient` 将 URLSession 同时适配到 `APIClient` 和 `APIUploadClient`。

行为说明：
- response headers 会被归一化为 `[String: String]` 便于查看。
- 上传通过 `AsyncStream<UploadProgress>` 暴露进度。
- 第一方 client 会将传输层失败包装为 `APIError.underlying`，并在可用时附带 `APIResponse`。
- 自定义 `APIClient` 可以抛出自己的错误；`APIProvider` 不会包装未知 client 错误。
- `APIProvider.uploadTask` 需要支持上传的 client。如果当前 client 不遵循 `APIUploadClient`，会抛出 `APIError.capabilityNotSupported`。

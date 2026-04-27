# v1.9.0 迁移指南

这份文档覆盖从 pre-1.0 API 线，尤其是 `v0.4.x`，迁移到 `v1.9.0`
时最容易影响编译和行为的变化。

`v1.9.0` 是 Moira 第一个正式稳定公开版本。它承接
`internal/v1.8.0` 之前的内部稳定化序列，并作为公开 1.x API 的基线。

## Package Products

核心能力继续使用 `Moira`：

```swift
import Moira
```

Alamofire-backed transport 已经拆到单独的 product：

```swift
import Moira
import MoiraAlamofire

let provider = APIProvider(
    client: AlamofireClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)
```

如果不需要 Alamofire 的传输层能力，可以直接使用 `Moira` 提供的
Foundation-only client：

```swift
let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)
```

## APIRequest

所有 `APIRequest` conformer 现在都需要显式声明执行方式：

```swift
var execution: RequestExecution { .request }
```

上传也通过同一个 request model 表达，只是 execution 变成 upload：

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

`RequestBuilder` 已经替换为 `URLRequestBuilder`。

```swift
let builder = URLRequestBuilder(baseURL: baseURL)
let provider = APIProvider(client: URLSessionClient(), builder: builder)
```

如果需要自定义构建规则，实现 `URLRequestBuilding`。

## RequestPayload

`RequestPayload` 现在更推荐使用静态工厂和链式写法。

```swift
let payload = RequestPayload.query("page", "1")
    .query("sort", "name")

let body = RequestPayload.json(CreateUser(name: "Moira"))
```

链式 body helper 会替换当前 body；query helper 会追加 query item。

## Uploads

传输层能力已经拆开：

- `APIClient` 只负责普通 request。
- `APIUploadClient` 负责 upload。

`APIProvider.uploadTask(_:)` 要求当前 client 同时 conform
`APIUploadClient`，否则会抛出 `APIError.capabilityNotSupported`。

```swift
let task = try await provider.uploadTask(UploadAvatarRequest(data: imageData))

for await progress in task.progress {
    print(progress.completedBytes)
}

let response = try await task.response()
```

上传响应会执行 raw response validation，但 upload 默认不进入普通 request 的
retry 流程。

## Plugins

插件现在拆成更窄的角色：

- `TransformPlugin` 通过 `prepareRequest(_:)` 和 `adaptRequest(_:)` 修改请求。
- `ResponseValidationPlugin` 校验 raw `APIResponse`。
- `ObserverPlugin` 只观察 lifecycle snapshot，不修改数据。

Retry 不再是 plugin，而是在 provider 上配置：

```swift
let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: baseURL),
    retryStrategy: MyRetryStrategy()
)
```

## Retry

`RetryStrategy` 用来决定 transport 或 raw response validation 失败后是否重试：

```swift
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry(RetryRequestBehavior)
    case retryAfter(TimeInterval, RetryRequestBehavior)
}
```

每次 decision 都会明确下一次 attempt 是复用当前 `URLRequest`，还是重新构建。

`prepareRequest(_:)`、request build、`adaptRequest(_:)`、typed decode 以及
upload validation 失败都不会进入普通 request retry 流程。

## 移除 Short-Circuit 和 Stub Hooks

`ShortCircuitPlugin` 已经移除。Provider 级 stub 和 short-circuit 能力不属于
`v1.9.0` API。

业务测试更推荐在 service 边界做 mock：

```swift
protocol UserServicing: Sendable {
    func profile(id: String) async throws -> User
}
```

也就是在应用测试里注入 mock service，而不是在 provider 层手动构造 raw HTTP
response。

## Error Handling

Moira 不再把所有未知错误统一包装成 `APIError.underlying`。

- Moira 自己定义的失败仍使用 `APIError`。
- 第一方 client 会在合适时把 transport failure 包装为 `APIError.underlying`，
  以便携带 response 信息。
- 自定义 client、plugin 和 validation 代码可以原样透出自己的错误。

调用方不应假设所有 provider failure 都是 `APIError`。

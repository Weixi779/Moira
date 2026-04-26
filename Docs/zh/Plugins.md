# 插件体系

Moira 将插件拆分为三类角色，每类职责清晰且可组合。`RequestPlugin` 是统一的标记协议，Provider 会收集并执行 Transform、ResponseValidation、Observer 插件；Retry 作为 Provider 策略单独配置。

## TransformPlugin

用于在发送前改写请求。

```swift
public protocol TransformPlugin: RequestPlugin {
    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest
}
```

典型用途：
- 注入鉴权 Header
- 统一路径或参数

## ResponseValidationPlugin

用于全局 raw response 校验。Validation 插件只检查 `APIResponse`，响应不可接受时抛错，不修改 response，也不负责 typed decode。

```swift
public protocol ResponseValidationPlugin: RequestPlugin {
    func validateResponse(_ response: APIResponse) async throws
}
```

典型用途：
- 统一校验可接受的状态码范围
- 拒绝缺少必要 header 的响应
- 在 typed decode 前拦截不合规的 raw response

## ObserverPlugin

用于观察生命周期，不做改写。

```swift
public protocol ObserverPlugin: RequestPlugin {
    func willSend(snapshot: RequestContext.Snapshot) async
    func didReceive(snapshot: RequestContext.Snapshot) async
    func didFail(snapshot: RequestContext.Snapshot) async
}
```

## RetryStrategy

用于在 transport 或 raw response validation 失败后决定是否重试。

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
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}
```

Retry 策略通过 `APIProvider(retryStrategy:)` 传入。未传入时使用 `NoRetryStrategy`，即不重试。请求准备、构建、适配、上传响应 validation 以及 typed decode 失败不会触发重试。每次重试决策都会决定下一次尝试复用当前 `URLRequest`，还是重新构建。

## 执行规则

- Transform：顺序执行。
- Response validation：顺序执行，遇到第一个抛错后停止。
- Observer：并发执行。
- Retry：Provider 策略决定是否重试以及是否重建请求。

## RequestContext

`RequestContext` 保存请求级状态，并提供只读快照供插件读取。快照不可变，适合在并发的 Observer 中使用。

```swift
public actor RequestContext {
    public let id: UUID
    public let target: any APIRequest
    public private(set) var startTime: Date

    public private(set) var request: URLRequest?
    public private(set) var response: APIResponse?
    public private(set) var error: Error?
    public private(set) var retryCount: Int
}
```

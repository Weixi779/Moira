# 插件体系

Moira 将插件拆分为两类角色，每类职责清晰且可组合。`RequestPlugin` 是统一的标记协议，Provider 会收集并执行 Transform、Observer 插件；Retry 作为 Provider 策略单独配置。

## TransformPlugin

用于改写请求或响应。

```swift
public protocol TransformPlugin: RequestPlugin {
    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest
    func adaptRequest(_ request: URLRequest) async throws -> URLRequest
    func processResponse(_ response: APIResponse) async throws -> APIResponse
}
```

典型用途：
- 注入鉴权 Header
- 统一路径或参数
- 响应数据的标准化处理

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

用于在 transport 或原始响应处理失败后决定是否重试。

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

Retry 策略通过 `APIProvider(retryStrategy:)` 传入。未传入时使用 `NoRetryStrategy`，即不重试。请求准备、构建、适配以及 typed decode 失败不会触发重试。每次重试决策都会决定下一次尝试复用当前 `URLRequest`，还是重新构建。

## 执行规则

- Transform：顺序执行。
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

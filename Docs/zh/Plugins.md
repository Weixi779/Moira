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
    func willSend(snapshot: RequestSnapshot) async
    func didReceive(snapshot: RequestSnapshot) async
    func didFail(snapshot: RequestSnapshot) async
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
    func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestSnapshot, error: Error, decision: RetryDecision) async
}
```

Retry 策略通过 `APIProvider(retryStrategy:)` 传入。未传入时使用 `NoRetryStrategy`，即不重试。初始请求准备、构建、适配、上传响应 validation 以及 typed decode 失败不会触发重试。每次重试决策都会决定下一次尝试复用当前 `URLRequest`，还是重新构建。

## 执行规则

- Transform：顺序执行。
- Response validation：顺序执行，遇到第一个抛错后停止。
- Observer：并发执行。
- `willSend`：只在 prepared request 即将交给 transport 时触发。
- Retry：Provider 策略决定是否重试以及是否重建请求。

## RequestSnapshot

`RequestSnapshot` 是 Observer 和 RetryStrategy 可读取的公开生命周期模型。`target` 始终是 transform 插件处理前的原始 target；`executionKind` 来自 prepared target，表示实际将被派发的执行路径。

```swift
public enum RequestExecutionKind: Sendable, Equatable {
    case request
    case upload
}

public struct RequestSnapshot: @unchecked Sendable {
    public let id: UUID
    public let target: any APIRequest
    public let executionKind: RequestExecutionKind
    public let attemptStartedAt: Date
    public let request: URLRequest?
    public let response: APIResponse?
    public let error: Error?
    public let retryCount: Int
}
```

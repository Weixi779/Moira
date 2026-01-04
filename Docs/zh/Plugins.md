# 插件体系

Moira 将插件拆分为四类角色，每类职责清晰且可组合。

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

## RetryPlugin

用于决定是否重试。

```swift
public enum RetryDecision: Sendable {
    case doNotRetry
    case retry
    case retryAfter(TimeInterval)
}

public protocol RetryPlugin: RequestPlugin {
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}
```

## ShortCircuitPlugin

用于缓存、Mock 或预制响应。

```swift
public enum ShortCircuitDecision: Sendable {
    case miss
    case hitResult(APIResponse, source: String? = nil)
    case hitError(Error, source: String? = nil)
}

public protocol ShortCircuitPlugin: RequestPlugin {
    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision
}
```

## 执行规则

- Transform：顺序执行。
- Observer：并发执行。
- Retry：第一个非 `doNotRetry` 决策生效。
- ShortCircuit：第一个命中生效。

## RequestContext

`RequestContext` 保存请求级状态，并提供只读快照供插件读取。

```swift
public actor RequestContext {
    public let id: UUID
    public let target: any APIRequest
    public let startTime: Date

    public private(set) var request: URLRequest?
    public private(set) var response: APIResponse?
    public private(set) var error: Error?
    public private(set) var retryCount: Int
}
```

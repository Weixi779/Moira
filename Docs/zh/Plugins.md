# 插件体系

Moira 将插件拆分为四类角色，每类职责清晰且可组合。`RequestPlugin` 是统一的标记协议，Provider 会收集并执行 Transform、Observer、ShortCircuit 插件；Retry 需要单独配置。

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

public enum RetryPolicy: Sendable {
    case reuseRequest
    case rebuildRequest
}

public protocol RetryPlugin: Sendable {
    var policy: RetryPolicy { get }
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision
    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async
}
```

Retry 插件通过 `APIProvider(retryPlugin:)` 传入，可选配置。

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
- Retry：可选插件决定是否重试以及是否重建请求。
- ShortCircuit：第一个命中生效。

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

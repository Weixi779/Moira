# 解码注入与短路参考（讨论 07）

## 1. 解码注入（默认 JSON + 小范围可插拔）
- **问题**：`JSONDecoder` 是具体类型，不是协议；API 绑死 JSON，后续遇到 JWT/纯文本/二进制会很别扭。
- **目标**：保留默认 JSON 体验，同时允许少数场景切换解码策略，避免“大一统 Decoder”带来的不确定行为。

### 推荐方案：小协议 + 默认实现
```swift
public protocol ResponseDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: ResponseDecoder {}

struct StringDecoder: ResponseDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard type == String.self else { throw DecodeError.unsupported }
        return String(data: data, encoding: .utf8) as! T
    }
}
```

### API 形态（默认 JSON，可替换）
```swift
func decode<T: Decodable>(
    _ type: T.Type,
    decoder: ResponseDecoder = JSONDecoder()
) throws -> T
```

### 设计要点
- 默认路径清晰：99% 走 JSONDecoder，不额外学习成本。
- 可扩展点明确：仅在需要时传入自定义 decoder（JWT/Plain String/自定义格式）。
- 避免“大而全 decoder”：不把所有格式和策略塞进一个总协议，减少复杂度。

## 2. 其他可借鉴点（对短路插件有启发）

### 2.1 优先级短路模型
- `swift-configuration` 的 MultiProvider 是“高优先级覆盖低优先级”，命中即返回。
- 对 Moira 可映射为：`ShortCircuitPlugin -> CacheProvider -> NetworkProvider`，命中即短路，未命中才继续。

### 2.2 Snapshot / 不可变视图
- 读取使用快照，避免中途数据被修改，保证一致性。
- 对缓存读取：命中后返回 `ResponseSnapshot`，避免后续插件修改导致不一致。

### 2.3 AccessReporter / 访问日志
- 访问路径和结果结构化记录，方便调试“为什么命中/没命中”。
- 对短路插件：记录命中来源（memory/disk/mock/plugin）和耗时，便于观测。

### 2.4 可选 Traits 思想
- 日志、重载、格式支持作为可选 traits 开启。
- 对 Moira：缓存、mock、重试、脱敏、观察可做成 trait/flag，避免核心依赖膨胀。

## 3. 短路返回形态（讨论结论）
- **短路必须返回最终结果**：命中（hit）时必须携带最终响应数据，否则无法真正提前返回。
- **返回结构保持轻量可扩展**：短路只返回一个“短路结果”，可自定义 payload，不强绑插件能力。

### 推荐形态
```swift
enum ShortCircuitDecision<Result> {
    case miss
    case hit(result: Result, source: String? = nil)
}
```

### 说明
- `result` 为最终响应（可直接返回给调用方）。
- `source` 可选，用于标记来源（cache/mock/其他插件），不做强类型枚举，避免写死扩展能力。

## 4. Mock 能力归属（讨论结论）
- **Mock 由外部注入层决定**：不要求 Target 内置 mockData，是否 mock 由 ShortCircuit/测试插件决定。
- **匹配方式可自由选择**：可通过 URL/identifier 进行映射，也可通过具体 target 类型判断。

### 推荐实现思路
```swift
// 方式 1：identifier 映射（声明式）
// ShortCircuitPlugin 接收 [String: Result<CoreResponse, Error>] 作为 mock 表

// 方式 2：matcher 闭包（灵活）
// (target: APIRequest) -> ShortCircuitDecision<CoreResponse>
```

## 5. 最小响应单元（讨论结论）
- **内部最小单元对齐 URLSession 语义**：使用 `Data + HTTPURLResponse?` 作为短路与网络的统一承载。
- **对外 APIResponse 仍保留扩展字段**：`APIResponse` 可继续包含 statusCode/headers/request/response 等。

### 推荐形态
```swift
struct CoreResponse {
    var data: Data
    var response: HTTPURLResponse?
}
```

## 6. Observer 与重试（讨论结论）
- **Observer 只观测，不做重试决策**：重试由 RetryPlugin/策略决定。
- **不新增 didRetry**：已有 willRetry 结果即可；每次重试会重新跑完整流程（含 willSend/didReceive）。
- **错误语义清晰**：只有最终失败才触发 `didFail`，其它重试中间态由 willRetry 反映。

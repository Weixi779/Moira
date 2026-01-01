# 待讨论与重构 Q&A（编号版）

> 将开放议题按主题编号，便于逐项拍板。

## 1. Mock / 短路 / 返回形态
1.1 **Mock 默认会渗透生产，怎么办？**  
　**A**：非核心问题，Moira 仅提供能力；是否启用由外部注入 ShortCircuit/Mock 插件决定。  
1.2 **Mock 能否走完整插件链？**  
　**A**：短路能力与 Mock 归属已在 07 落地，见 `docs/07-decoder-and-shortcircuit.md`。  
1.3 **缓存/预制响应如何接入？**  
　**A**：短路优先级与返回形态已在 07 落地，见 `docs/07-decoder-and-shortcircuit.md`。  
1.4 **返回类型会耦合上下文，怎么拆？**  
　**A**：对外最小接口：`request(_:) async -> Void` 与 `request<T: Decodable>(_:) async -> T`；内部保留 `publish(_:) async -> APIResponse`（含上下文）。若仍嫌耦合，对外可收敛为 `(Data, HTTPURLResponse?)` 或纯 `Data`；fire-and-forget 可选但需定义错误传递。

## 2. Request / Task 模型
2.1 **RequestTask 分支过多，如何收敛？**  
　**A**：主推 `.encodable` + `.urlQuery`，复合场景用参数 struct；上传拆成独立 `UploadTask`。  
2.2 **APIRequest 命名与 baseURL 语义不清？**  
　**A**：考虑重命名为 `Endpoint`/`EndpointDescriptor`；`baseURL` 统一为 Provider 默认值，覆盖时显式 `overrideBaseURL`。  
2.3 **HTTP 校验与业务校验混淆？**  
　**A**：`ValidationType` 更名 `HTTPValidationPolicy`，仅管 HTTP 层；业务校验上移。

## 3. 插件流水线与错误处理
3.1 **插件顺序/错误策略未明？**  
　**A**：固定 `prepare -> adapt -> process` 阶段，定义遇错短路/回退规则；提供可选 trace。  
3.2 **Progress 回调线程不清晰？**  
　**A**：明确为同步回调，UI 更新需自行派发主线程。  
3.3 **错误处理与重试如何抽象？**  
　**A**：Retry 纳入 `ErrorHandlingPlugin`，支持 `retry/backoff/fail-fast/transform error` 决策，可选 `mapError` 统一错误域。  
3.4 **插件职责需要分层吗？**  
　**A**：是。Transform（改写）、Observer（观测）、ErrorHandling（重试/映射）、ShortCircuit（缓存/Mock/预制响应）、Progress（进度）五类，减少交叉。
3.5 **“prepare” 命名不直观？**  
　**A**：可考虑更名为 `configureEndpoint`/`preprocessTarget` 等，文档明确职责：在生成最终请求前对 Target/Endpoint 做统一改写或注入，与 Moya 的 `endpointClosure` 对应。

## 4. Mock 数据形态
4.1 **如何模拟真实错误/包装 JSON？**  
　**A**：`MockResponse` 支持 `httpError(statusCode,data)` 与 `transportError(Error)`，示例覆盖 `{code,msg,data}` 等包装形态。

## 5. 缓存与命名空间
5.1 **Cache Key 如何规范？**  
　**A**：统一 `namespace.path.queryHash` 形式，便于缓存/失效/监控。  
5.2 **多级 Provider 怎么合并？**  
　**A**：参考 07 的短路优先级模型，规划内存/磁盘/网络的合并与订阅策略。

## 6. 平台兼容
6.1 **最低版本怎么定？**  
　**A**：`swift-configuration` 为 iOS 18+；需明确 Moira 的目标最低版本与降级方案，避免无意抬高部署目标。

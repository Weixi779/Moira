# 生命周期与执行模型

Moira 的架构核心仍然是 `URLRequest` 的组装流程。它尽量贴近原生拼装方式，用更语义化的步骤覆盖常见 HTTP 关注点，而不是规定应用层架构。

Moira 对每次请求执行固定的流程，便于插件与错误处理对齐。

## 基本流程

```
prepare -> build -> adapt -> willSend
  -> execute -> validate -> didReceive
  -> on error: shouldRetry? -> willRetry -> retry or didFail
```

## 重试

- transport 或 raw response validation 失败后，会询问 RetryStrategy 是否重试。
- 每次重试决策会决定重建或复用请求，然后再次发送。
- 请求准备、构建、适配以及 typed decode 失败不会触发重试。
- 每次重试在请求重建或复用后都会重新触发 `willSend`。
- `willRetry` 在下一次尝试前触发。
- 最终失败只触发一次 `didFail`。
- 上传与下载默认不参与重试。上传响应会执行 validation，但上传 validation 失败不会触发重试。

## 可观测性

- Observer 只能读取 `RequestContext.Snapshot`。
- Observer 以并发方式执行。

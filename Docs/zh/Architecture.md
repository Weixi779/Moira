# 生命周期与执行模型

Moira 对每次请求执行固定的流程，便于插件与错误处理对齐。

## 基本流程

```
prepare -> build -> adapt -> willSend
  -> shortCircuit? -> execute -> process -> didReceive
  -> on error: shouldRetry? -> willRetry -> retry or didFail
```

## Short-circuit

- 在 `willSend` 之后评估。
- 命中即返回，不触发网络请求。
- 命中结果触发 `didReceive`，命中错误触发 `didFail`。

## 重试

- 失败后询问 RetryPlugin。
- 每次重试都会重新走 client 执行路径。
- `willRetry` 在下一次尝试前触发。
- 最终失败只触发一次 `didFail`。

## 可观测性

- Observer 只能读取 `RequestContext.Snapshot`。
- Observer 以并发方式执行。

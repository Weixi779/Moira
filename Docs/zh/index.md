# Moira 中文文档

Moira 是一个面向 Swift Concurrency 的轻量网络层，适合希望保留 Moya-style API 建模、同时迁移到 `async/await` 与现代 `URLSession` 流程的 iOS/macOS 项目。

这里是中文文档入口。英文文档见 [Docs/index.md](../index.md)。

## 从这里开始

- [快速开始](Getting-Started.md)：安装 Moira，创建 `APIProvider`，完成第一个 typed request。
- [核心类型](Core-Types.md)：理解 `APIRequest`、`RequestPayload`、`RequestExecution`、`APIResponse` 和 `APIError`。
- [请求构建](Request-Building.md)：了解 `URLRequestBuilder` 如何处理 path、query、headers、timeout 和 body。

## 迁移与架构边界

- [迁移指南](Migration-Guide.md)：从旧 API 线迁移到当前公开 API 基线。
- [生命周期模型](Architecture.md)：理解请求生命周期和扩展点边界。
- [Service 层建议](Service-Layer.md)：把 Moira 保持在网络层，把业务 mock 放到 Service 边界。

## 扩展能力

- [插件体系](Plugins.md)：使用 transform、validation 和 observer plugin。
- [Client 适配](Clients.md)：了解 `URLSessionClient`、可选 client adapter 和自定义 transport client。

## 相关入口

- [中文 README](../../README.zh.md)
- [English README](../../README.md)
- [English documentation index](../index.md)

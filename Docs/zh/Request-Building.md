# 请求构建

Moira 提供了一套完整的 `URLRequest` 组装流程，目标是让构建过程更 API 化、更语义化，但不强制你依赖某种架构。它尽量贴近原生 `URLRequest` 的拼装方式，强调简单复用，并只抽象出最常见的 HTTP 概念，即使看起来组件数量不少。

`URLRequestBuilder` 负责将 `APIRequest` 转为 `URLRequest`，规则固定且可预期。`APIProvider` 也接受任意 `URLRequestBuilding` 实现，而 `URLRequestBuilder` 是默认提供的那一个。

## URL 解析

- 先取 `target.baseURL`，为空时使用 Provider 的 baseURL。
- `path` 会被视为 endpoint path，并追加到 baseURL 当前 path 之后。
- `path` 即使以 `/` 开头，也不会回退到 host 根路径。
- 如果 baseURL 已经带有 query，`payload.query` 会按顺序追加在后面，不做去重。

## Header 与超时

- `headers` 原样写入。
- `timeout` 映射到 `URLRequest.timeoutInterval`。
- `Content-Type` 只在缺失时自动设置。

## Body 编码

`RequestPayload.Body` 的编码策略：

- `none`：不写入 body
- `json`：通过 `JSONEncodable` 使用 `JSONEncoder` 编码
- `urlEncodedForm`：`application/x-www-form-urlencoded; charset=utf-8`
- `data`：`application/octet-stream`
- `upload`：multipart 由 client 处理边界

## Content-Type 规则

- JSON：`application/json`
- URL 表单：`application/x-www-form-urlencoded; charset=utf-8`
- 原始数据：`application/octet-stream`
- multipart：构建阶段不设置

## 错误

非法路径会映射为 `APIError.requestBuildingFailed`。

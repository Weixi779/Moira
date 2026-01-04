# 请求构建

`RequestBuilder` 负责将 `APIRequest` 转为 `URLRequest`。

## URL 解析

- 先取 `target.baseURL`，为空时使用 Provider 的 baseURL。
- `path` 相对 baseURL 解析。
- `payload.query` 转为 URL query items。

## Header 与超时

- `headers` 原样写入。
- `timeout` 映射到 `URLRequest.timeoutInterval`。
- `Content-Type` 只在缺失时自动设置。

## Body 编码

`RequestPayload.Body` 的编码策略：

- `none`：不写入 body
- `json`：使用 `JSONEncoder` 编码
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

# Moira

Moira 是一个基于 Swift Concurrency 的轻量网络层，提供清晰的请求描述、可预测的生命周期以及可插拔的插件体系。

## 主要能力

- 请求描述：`APIRequest` + `RequestPayload`
- 请求构建：`RequestBuilder`
- 插件体系：Transform / Observer / Retry / ShortCircuit
- 解码注入：`ResponseDecoder`
- 上传/下载进度：`RequestTask.progress`

## 快速示例

```swift
import Moira

enum UserAPI: APIRequest {
    case profile(id: String)

    var path: String { "/users/\(id)" }
    var method: RequestMethod { .get }
    var payload: RequestPayload { RequestPayload() }
}

let baseURL = URL(string: "https://api.example.com")!
let provider = APIProvider(
    client: AlamofireClient(),
    builder: RequestBuilder(baseURL: baseURL)
)

let user: User = try await provider.request(
    UserAPI.profile(id: "123"),
    decoder: JSONDecoder()
)
```

## 文档

英文：
- `Docs/Getting-Started.md`
- `Docs/Core-Types.md`
- `Docs/Plugins.md`
- `Docs/Request-Building.md`
- `Docs/Clients.md`
- `Docs/Architecture.md`

中文：
- `Docs/zh/Getting-Started.md`
- `Docs/zh/Core-Types.md`
- `Docs/zh/Plugins.md`
- `Docs/zh/Request-Building.md`
- `Docs/zh/Clients.md`
- `Docs/zh/Architecture.md`

## 构建与测试

```bash
swift build
swift test
```

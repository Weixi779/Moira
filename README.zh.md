# Moira

Moira 是一个基于 Swift Concurrency 的轻量网络层，
把 `URLRequest` 的组装过程做成更语义化、更易复用的流程，但不强制你依赖某种架构。

## 为什么是 Moira

Moira 希望把网络层做得更薄，同时让请求的构建与流程可组合、可复用。
这是对 `Moya` 之后网络层范式变化的一次回应。
设计背景见：[文章](https://weixi779.github.io/2026/01/05/%E3%80%8CiOS%E3%80%8D%E7%BD%91%E7%BB%9C%E5%B1%82%E5%B7%A5%E7%A8%8B%E8%8C%83%E5%BC%8F%E8%BF%81%E7%A7%BB/)

## 主要能力

- 请求描述：`APIRequest` + `RequestPayload`
- 规则稳定的请求构建：`RequestBuilder`
- 插件体系：Transform / Observer / Retry / ShortCircuit
- 默认解码：`ResponseDecoder`
- 上传/下载进度：`RequestTask<APIResponse>.progress`

## 快速示例

```swift
import Moira

enum UserAPI: APIRequest {
    case profile(id: String)
    case search(query: String)
    case updateProfile(id: String, payload: UpdateProfile)

    var path: String {
        switch self {
        case .profile(let id):
            return "/users/\(id)"
        case .search:
            return "/users/search"
        case .updateProfile(let id, _):
            return "/users/\(id)"
        }
    }

    var method: RequestMethod {
        switch self {
        case .profile, .search:
            return .get
        case .updateProfile:
            return .patch
        }
    }

    var payload: RequestPayload {
        switch self {
        case .profile:
            return RequestPayload()
        case .search(let query):
            return RequestPayload().appendingQueryItem(URLQueryItem(name: "q", value: query))
        case .updateProfile(_, let body):
            return RequestPayload().withJSON(body)
        }
    }
}

struct UpdateProfile: Encodable, Sendable {
    let name: String
}

let baseURL = URL(string: "https://api.example.com")!
let provider = APIProvider(
    client: AlamofireClient(),
    builder: RequestBuilder(baseURL: baseURL)
)

let user: User = try await provider.request(UserAPI.profile(id: "123"))
```

## Payload 示例

```swift
let queryPayload = RequestPayload()
    .appendingQueryItems([URLQueryItem(name: "page", value: "1")])

let formPayload = RequestPayload()
    .withURLEncodedForm([URLQueryItem(name: "q", value: "swift")])

let dataPayload = RequestPayload()
    .withData(Data("raw".utf8))
```

## 获取原始响应

```swift
let response = try await provider.requestResponse(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## 上传/下载与进度

```swift
let request = UploadAPI.data(Data("payload".utf8))
let task = try await provider.requestTask(request)

if let progress = task.progress {
    Task {
        for await update in progress {
            print(update.completedBytes)
        }
    }
}

let response = try await task.response()
print(response.statusCode)
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

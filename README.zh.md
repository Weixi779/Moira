# Moira

![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20macOS%2013.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![SPM Support](https://img.shields.io/badge/SPM-Supported-brightgreen) ![License](https://img.shields.io/github/license/Weixi779/Moira)

[English](README.md) | 简体中文

Moira 是一个面向 Swift Concurrency 的轻量网络层，
把 `URLRequest` 的组装过程做成更语义化、更易复用的流程，但不强制你依赖某种架构。

## 为什么是 Moira

Moira 带着我对 `Moya` 的致敬。
我曾经从 Moya 的接口建模思想里受益很多，但随着时间推移，维护状态、并发时代能力缺口和工程接入成本，让它越来越难适配现代项目。

Moira 是这次迁移后的落地选择：
- 网络层保持轻薄、可替换
- 保留语义化的 API 描述与可组合能力
- 全面拥抱 async/await 语境下的请求流程与生命周期扩展点

设计背景见：[「iOS」网络层工程范式迁移](https://weixi779.github.io/2026/01/05/%E3%80%8CiOS%E3%80%8D%E7%BD%91%E7%BB%9C%E5%B1%82%E5%B7%A5%E7%A8%8B%E8%8C%83%E5%BC%8F%E8%BF%81%E7%A7%BB/)

## 主要能力

- 请求描述：`APIRequest` + `RequestPayload`
- 规则稳定的请求构建：`URLRequestBuilder`
- 插件体系：Transform / Observer / Retry
- 默认解码：`ResponseDecoder`
- 上传与进度：`UploadTask<APIResponse>`

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
            return .query("q", query)
        case .updateProfile(_, let body):
            return .json(body)
        }
    }

    var execution: RequestExecution { .request }
}

struct UpdateProfile: Encodable, Sendable {
    let name: String
}

let baseURL = URL(string: "https://api.example.com")!
let provider = APIProvider(
    client: AlamofireClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)

let user: User = try await provider.request(UserAPI.profile(id: "123"))
```

## Payload 示例

```swift
let queryPayload: RequestPayload = .query("page", "1")
    .query("sort", "name")

let formPayload: RequestPayload = .formEncoded([URLQueryItem(name: "q", value: "swift")])

let dataPayload: RequestPayload = .data(Data("raw".utf8))
```

## 获取原始响应

```swift
let response = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## 上传与进度

```swift
struct UploadAvatarRequest: APIRequest {
    let path = "/avatar"
    let method: RequestMethod = .post
    let payload = RequestPayload()
    let execution: RequestExecution

    init(source: UploadSource) {
        self.execution = .upload(source)
    }
}

let request = UploadAvatarRequest(source: .data(imageData))
let task = try await provider.uploadTask(request)

Task {
    for await update in task.progress {
        print(update.completedBytes)
    }
}

let response = try await task.response()
print(response.statusCode)
```

## 推荐的 Service 封装

Moira 有意聚焦在 `APIRequest` 和 `APIProvider` 这一层。应用通常只需要在其上补一层很薄的 service，并把 mock 放在 service 边界即可。

```swift
protocol UserServicing: Sendable {
    func profile(id: String) async throws -> User
}

struct UserService: UserServicing {
    let requester: any APIRequesting

    func profile(id: String) async throws -> User {
        try await requester.request(UserAPI.profile(id: id))
    }
}

struct MockUserService: UserServicing {
    let result: Result<User, Error>

    func profile(id: String) async throws -> User {
        try result.get()
    }
}
```

## 文档

Moira 内置了完整的中英文文档，方便快速落地与深度扩展。

导航入口：
- 英文文档索引：`Docs/index.md`
- 中文文档索引：`Docs/zh/index.md`

核心文档：
- 快速开始：`Docs/Getting-Started.md` / `Docs/zh/Getting-Started.md`
- 核心类型：`Docs/Core-Types.md` / `Docs/zh/Core-Types.md`
- 插件体系：`Docs/Plugins.md` / `Docs/zh/Plugins.md`
- 请求构建：`Docs/Request-Building.md` / `Docs/zh/Request-Building.md`
- Client 适配：`Docs/Clients.md` / `Docs/zh/Clients.md`
- 架构设计：`Docs/Architecture.md` / `Docs/zh/Architecture.md`
- Service 层建议：`Docs/Service-Layer.md` / `Docs/zh/Service-Layer.md`

## 构建与测试

```bash
swift build
swift test
```

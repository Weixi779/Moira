# Moira

![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20macOS%2013.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![SPM Support](https://img.shields.io/badge/Swift%20Package%20Manager-Supported-brightgreen) ![License](https://img.shields.io/github/license/Weixi779/Moira)

[English](README.md) | 简体中文

**面向 Swift Concurrency 的 Moya-style API 建模。**

Moira 是一个轻量 Swift 网络层，适合正在把 iOS/macOS 网络代码迁移到 `async/await` 和现代 `URLSession` 流程的项目。它保留 Moya 带来的“用类型描述 API”的工程价值，但把执行模型、请求构建、生命周期扩展和解码流程放在 Swift Concurrency 语境下重新整理。

它不是 Alamofire 的替代品，也不是大而全的企业级框架。Moira 的目标是 thin, replaceable, composable：薄、可替换、可组合。

## 为什么 Moya 之后还需要 Moira

Moya 的 `TargetType` 思路影响了很多 iOS 项目：把 path、method、task、headers 等接口信息集中建模，避免业务代码里散落 `URLRequest` 细节。这一点仍然有价值。

但在 Swift Concurrency 之后，很多项目会遇到新的工程诉求：

- 请求入口希望天然是 `async throws`，而不是从回调或响应式封装再桥接。
- `URLSession` 自身已经足够强，网络层更需要稳定的 request builder，而不是更厚的封装。
- 插件需要有清晰职责：改请求、校验响应、观察生命周期、决定重试，不应该混在一个模糊扩展点里。
- mock 更适合放在业务 Service 边界，而不是强迫 provider 承担业务 fixture。

Moira 就是这个取舍下的轻量网络层。

## Moira 解决什么问题

- 用 `APIRequest` 明确描述一个接口。
- 用 `RequestPayload` 表达 query、JSON body、form body 和 raw data。
- 用 `URLRequestBuilder` 统一、稳定地构建 `URLRequest`。
- 用 `APIProvider` 通过 `async/await` 执行请求并解码。
- 用 `TransformPlugin`、`ResponseValidationPlugin`、`ObserverPlugin` 和 `RetryStrategy` 拆开生命周期职责。
- 用 `UploadTask` 支持上传进度。

Moira 不规定你的应用必须使用 Clean Architecture、MVVM、Redux 或任何其他上层架构。它只负责网络层这一小段边界。

## 适合什么项目

Moira 适合这些场景：

- 你喜欢 Moya 的 API 建模方式，但希望网络执行流是 async/await-native。
- 你正在做 Moya migration，希望迁移到更现代的 `URLSession` + Swift Concurrency 代码。
- 你需要一个小型 API client 层，统一 request builder、response validation、observer、retry 和 decoder。
- 你的团队希望网络层可替换，不希望把业务 mock、页面状态管理、应用架构都塞进网络库。
- 你希望 Swift Package Manager 直接集成，不额外引入业务层依赖。

## 不适合什么场景

Moira 不适合这些需求：

- 你需要一个功能非常完整、策略内置很多的网络大框架。
- 你想要一个 Moya 或 Alamofire 的 drop-in replacement。
- 你希望 provider 层内置大量 stub、fixture、mock 和业务测试能力。
- 你希望网络库顺便规定应用分层、状态管理和依赖注入方式。

这些能力可以在应用层自己组织。Moira 保持网络层足够薄，后续替换成本才低。

## 安装

通过 Swift Package Manager 添加：

```swift
dependencies: [
    .package(url: "https://github.com/Weixi779/Moira.git", from: "1.9.0")
]
```

在 target 中依赖核心 product：

```swift
.product(name: "Moira", package: "Moira")
```

Foundation-only 的基础用法：

```swift
import Moira

let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: URL(string: "https://api.example.com")!)
)
```

如果项目确实需要 Alamofire-backed transport，可以额外使用 `MoiraAlamofire` product；核心 `Moira` 不依赖它。

## 快速开始

把接口建模成 `APIRequest`，然后用 `try await` 请求。

```swift
import Foundation
import Moira

struct User: Decodable, Sendable {
    let id: String
    let name: String
}

struct UpdateProfile: Encodable, Sendable {
    let name: String
}

enum UserAPI: APIRequest {
    case profile(id: String)
    case search(query: String)
    case updateProfile(id: String, body: UpdateProfile)

    var path: String {
        switch self {
        case .profile(let id), .updateProfile(let id, _):
            return "/users/\(id)"
        case .search:
            return "/users/search"
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

let baseURL = URL(string: "https://api.example.com")!
let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: baseURL)
)

let user: User = try await provider.request(UserAPI.profile(id: "123"))
```

也可以拿到原始响应：

```swift
let response: APIResponse = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## RequestPayload

`RequestPayload` 让 query 和 body 的表达保持明确：

```swift
let query = RequestPayload.query("page", "1")
    .query("sort", "name")

let json = RequestPayload.json(UpdateProfile(name: "Moira"))

let form = RequestPayload.formEncoded([
    URLQueryItem(name: "email", value: "hello@example.com")
])

let raw = RequestPayload.data(Data("raw".utf8))
```

query helper 会追加 query item；body helper 会设置或替换 body。

## 请求生命周期

Moira 把生命周期拆成清晰的几个环节：

```text
APIRequest
  -> TransformPlugin.prepareRequest
  -> URLRequestBuilder
  -> TransformPlugin.adaptRequest
  -> APIProvider
  -> URLSessionClient
  -> ResponseValidationPlugin
  -> ObserverPlugin
  -> ResponseDecoder
```

`RetryStrategy` 配在 `APIProvider` 上，用于普通请求的 transport failure 和 raw response validation failure。typed decoding 发生在 raw validation 之后。

## 上传与进度

上传仍然使用同一个 request model，只是把 `execution` 设置为 `.upload`。

```swift
struct UploadAvatarRequest: APIRequest {
    let path = "/avatar"
    let method: RequestMethod = .post
    let payload = RequestPayload()
    let execution: RequestExecution

    init(data: Data) {
        execution = .upload(.data(data))
    }
}

let task = try await provider.uploadTask(UploadAvatarRequest(data: imageData))

Task {
    for await progress in task.progress {
        print(progress.completedBytes, progress.totalBytes as Any)
    }
}

let response = try await task.response()
print(response.statusCode)
```

## 推荐的 Service Layer 边界

Moira 建议停在网络层，不把业务 mock 做进 provider。应用层可以在 Moira 之上保留一层 Service：

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

这样测试可以 mock `UserServicing`，业务代码不需要感知底层是 Moira、URLSession 还是其他实现。

## 从 TargetType 思维迁移到 APIRequest

迁移时不要追求逐字段机械翻译。更推荐按职责迁移：

- `TargetType` 的 endpoint 描述迁移为 `APIRequest`。
- `task` / `parameters` 迁移为 `RequestPayload`。
- path、query、body、headers、timeout 由 `URLRequestBuilder` 统一构建。
- provider 调用改为 `try await provider.request(...)`。
- Moya plugin 中的逻辑拆到 transform、validation、observer 或 retry。
- 业务 mock 迁移到 Service protocol，而不是留在 provider 层。

更多细节见 [迁移指南](Docs/zh/Migration-Guide.md) 和 [Service 层建议](Docs/zh/Service-Layer.md)。

## 文档

入口：

- [中文文档入口](Docs/zh/index.md)
- [English documentation index](Docs/index.md)

核心文档：

- [快速开始](Docs/zh/Getting-Started.md)
- [迁移指南](Docs/zh/Migration-Guide.md)
- [核心类型](Docs/zh/Core-Types.md)
- [请求构建](Docs/zh/Request-Building.md)
- [插件体系](Docs/zh/Plugins.md)
- [Client 适配](Docs/zh/Clients.md)
- [生命周期模型](Docs/zh/Architecture.md)
- [Service 层建议](Docs/zh/Service-Layer.md)

设计背景：[「iOS」网络层工程范式迁移](https://weixi779.github.io/2026/01/05/%E3%80%8CiOS%E3%80%8D%E7%BD%91%E7%BB%9C%E5%B1%82%E5%B7%A5%E7%A8%8B%E8%8C%83%E5%BC%8F%E8%BF%81%E7%A7%BB/)

## 要求

- Swift 5.9+
- iOS 16+
- macOS 13+
- Swift Package Manager

## 构建与测试

```bash
swift build
swift test
```

集成测试会访问 `https://httpbin.org`，需要网络环境。

## License

Moira 基于 [MIT License](LICENSE) 发布。

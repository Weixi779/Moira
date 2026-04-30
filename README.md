# Moira

![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20macOS%2013.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![SPM Support](https://img.shields.io/badge/Swift%20Package%20Manager-Supported-brightgreen) ![License](https://img.shields.io/github/license/Weixi779/Moira)

English | [简体中文](README.zh.md)

**Moya-style API modeling for Swift Concurrency.**

Moira is a lightweight Swift networking layer for teams that want explicit API modeling, native async await networking (`async` / `await`), and predictable `URLSession`-based request construction without adopting a large framework. It is useful for iOS networking and macOS API client code where `APIRequest` values describe endpoints, `URLRequestBuilder` builds stable `URLRequest` instances, and `APIProvider` executes them through Swift Concurrency.

For teams searching for a respectful Moya alternative during a Moya migration, Moira keeps the useful idea of semantic endpoint modeling while moving the request flow to modern async/await and a thin, replaceable design. It is distributed with Swift Package Manager.

## Why Moira

Many Swift networking stacks still sit between two worlds:

- Moya popularized clear endpoint modeling, but many projects now want async/await-native flow.
- Direct `URLSession` code is reliable, but repeated request building, payload encoding, validation, observation, retry, and decoding logic can spread quickly.
- Large networking frameworks can be the right choice for some apps, but not every team wants a broad abstraction surface.

Moira focuses on the small middle layer:

- `APIRequest` describes what an endpoint means.
- `RequestPayload` describes query items, JSON body, form body, or raw data.
- `URLRequestBuilder` turns request models into predictable `URLRequest` values.
- `APIProvider` executes requests and decodes responses with async/await.
- Lifecycle hooks stay composable: `TransformPlugin`, `ResponseValidationPlugin`, `ObserverPlugin`, and `RetryStrategy`.

The goal is thin, replaceable, composable Swift networking, not an application architecture framework.

## When to Use Moira

Use Moira when you want:

- A small API client layer over `URLSession`.
- Swift Concurrency first networking with `async` / `await`.
- Moya-style request modeling without carrying a large compatibility surface.
- Centralized request builder behavior for paths, query items, headers, timeouts, and bodies.
- Explicit extension points for request transform, response validation, observation, retry, and decoding.
- A network layer that does not force Clean Architecture, MVVM, Redux, or any app-level architecture.
- A practical path for Moya migration while keeping business APIs readable.

## When Not to Use Moira

Moira may not be the right fit if you need:

- A full-featured networking framework with broad built-in policies.
- Request stubbing, business mocking, or fixture management inside the provider layer.
- A replacement for your app architecture.
- A transport abstraction that hides all `URLSession` concepts.
- A direct drop-in replacement for Moya or Alamofire.

Moira is intentionally narrow. For application tests, prefer mocking at a service boundary above Moira.

## Installation

Add Moira with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Weixi779/Moira.git", from: "1.9.0")
]
```

Then add the core product to your target:

```swift
.product(name: "Moira", package: "Moira")
```

Core usage is Foundation-only:

```swift
import Moira

let provider = APIProvider(
    client: URLSessionClient(),
    builder: URLRequestBuilder(baseURL: URL(string: "https://api.example.com")!)
)
```

An optional `MoiraAlamofire` product is available if a project needs an Alamofire-backed transport, but Moira's core design does not require it.

## Quick Start

Model each endpoint as an `APIRequest`, then execute it with `try await`.

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

You can also request the raw response:

```swift
let response: APIResponse = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## Request Payloads

`RequestPayload` keeps query and body modeling explicit:

```swift
let query = RequestPayload.query("page", "1")
    .query("sort", "name")

let json = RequestPayload.json(UpdateProfile(name: "Moira"))

let form = RequestPayload.formEncoded([
    URLQueryItem(name: "email", value: "hello@example.com")
])

let raw = RequestPayload.data(Data("raw".utf8))
```

Query helpers append query items. Body helpers set or replace the body.

## Request Lifecycle

Moira keeps the request lifecycle visible:

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

Retry is configured with `RetryStrategy` on `APIProvider`. It applies to regular request transport and raw response validation failures. Typed decoding happens after raw response validation.

## Upload with Progress

Uploads use the same request model, with `execution` set to `.upload`.

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

## Recommended Service Layer

Moira is the networking layer. In app code, keep business-facing APIs in a service layer above it. That gives tests a stable mocking boundary without making `APIProvider` responsible for business fixtures.

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

This keeps Moira thin and replaceable while letting application code choose its own architecture.

## Moya Migration

Moira is inspired by the API modeling discipline many teams learned from Moya. It is not a drop-in replacement, and it does not try to mirror every Moya feature. A migration usually works best when you move endpoint definitions first, then move plugins, validation, retry, and service mocks deliberately.

Common mapping:

- `TargetType` endpoint description becomes `APIRequest`.
- `task` and `parameters` become `RequestPayload`.
- request construction moves into `URLRequestBuilder`.
- provider execution becomes `try await provider.request(...)`.
- plugin behavior is split into transform, validation, observation, and retry roles.
- business mocks usually move above Moira into service protocols.

Read the [Migration Guide](Docs/Migration-Guide.md) and [Service Layer Guidance](Docs/Service-Layer.md) for the current API baseline.

## Documentation

Start here:

- [English documentation index](Docs/index.md)
- [中文文档入口](Docs/zh/index.md)

Core guides:

- [Getting Started](Docs/Getting-Started.md)
- [Migration Guide](Docs/Migration-Guide.md)
- [Core Types](Docs/Core-Types.md)
- [Request Building](Docs/Request-Building.md)
- [Plugins](Docs/Plugins.md)
- [Clients](Docs/Clients.md)
- [Architecture](Docs/Architecture.md)
- [Service Layer Guidance](Docs/Service-Layer.md)

Design background in Chinese: [「iOS」网络层工程范式迁移](https://weixi779.github.io/2026/01/05/%E3%80%8CiOS%E3%80%8D%E7%BD%91%E7%BB%9C%E5%B1%82%E5%B7%A5%E7%A8%8B%E8%8C%83%E5%BC%8F%E8%BF%81%E7%A7%BB/)

## Requirements

- Swift 5.9+
- iOS 16+
- macOS 13+
- Swift Package Manager

## Build and Test

```bash
swift build
swift test
```

Integration tests may hit `https://httpbin.org` and require network access.

## License

Moira is released under the [MIT License](LICENSE).

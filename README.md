# Moira

![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20macOS%2013.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![SPM Support](https://img.shields.io/badge/SPM-Supported-brightgreen) ![License](https://img.shields.io/github/license/Weixi779/Moira)

English | [简体中文](README.zh.md)

Moira is a lightweight networking layer built for Swift Concurrency.
It keeps request construction explicit and composable without forcing application architecture choices.

## Why Moira

Moira carries a personal tribute to `Moya`.
I learned a lot from its API modeling ideas, but over time the maintenance burden, concurrency-era gaps, and growing integration friction made it hard to continue relying on it in modern projects.

Moira is the practical answer to that transition:
- Keep the networking layer thin and replaceable
- Preserve semantic API description and composability
- Embrace async/await-native request flow and clear lifecycle extension points

Design background: [「iOS」网络层工程范式迁移](https://weixi779.github.io/2026/01/05/%E3%80%8CiOS%E3%80%8D%E7%BD%91%E7%BB%9C%E5%B1%82%E5%B7%A5%E7%A8%8B%E8%8C%83%E5%BC%8F%E8%BF%81%E7%A7%BB/)

## Highlights

- Request description: `APIRequest` + `RequestPayload`
- Predictable build rules: `URLRequestBuilder`
- Pluggable lifecycle: Transform / Observer / Retry / ShortCircuit
- Default decoding via `ResponseDecoder`
- Upload with progress via `UploadTask<APIResponse>`

## Quick Example

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

## Payload Examples

```swift
let queryPayload = RequestPayload()
    .appendingQueryItems([URLQueryItem(name: "page", value: "1")])

let formPayload = RequestPayload()
    .withURLEncodedForm([URLQueryItem(name: "q", value: "swift")])

let dataPayload = RequestPayload()
    .withData(Data("raw".utf8))
```

## Raw Response

```swift
let response = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## Upload with Progress

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

## Docs

Moira ships with built-in documentation for both Chinese and English readers.

Index:
- English docs index: `Docs/index.md`
- Chinese docs index: `Docs/zh/index.md`

Core docs:
- Getting Started: `Docs/Getting-Started.md` / `Docs/zh/Getting-Started.md`
- Core Types: `Docs/Core-Types.md` / `Docs/zh/Core-Types.md`
- Plugins: `Docs/Plugins.md` / `Docs/zh/Plugins.md`
- Request Building: `Docs/Request-Building.md` / `Docs/zh/Request-Building.md`
- Clients: `Docs/Clients.md` / `Docs/zh/Clients.md`
- Architecture: `Docs/Architecture.md` / `Docs/zh/Architecture.md`

## Build & Test

```bash
swift build
swift test
```

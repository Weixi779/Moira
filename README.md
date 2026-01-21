# Moira

Moira is a lightweight networking layer built on Swift Concurrency.
It turns `URLRequest` assembly into a semantic, reusable pipeline without prescribing any application architecture.

## Why Moira

Moira keeps the networking layer thin while making request assembly explicit and composable.
It is a response to the post-`Moya` shift toward a lighter, async/await-native pipeline.
Background: [essay](https://weixi779.github.io/2026/01/05/%E3%80%8CiOS%E3%80%8D%E7%BD%91%E7%BB%9C%E5%B1%82%E5%B7%A5%E7%A8%8B%E8%8C%83%E5%BC%8F%E8%BF%81%E7%A7%BB/)

## Highlights

- Request description: `APIRequest` + `RequestPayload`
- Predictable build rules: `RequestBuilder`
- Pluggable lifecycle: Transform / Observer / Retry / ShortCircuit
- Default decoding via `ResponseDecoder`
- Upload/download progress via `RequestTask.progress`

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
let response = try await provider.requestResponse(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## Upload/Download with Progress

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

## Docs

English:
- `Docs/Getting-Started.md`
- `Docs/Core-Types.md`
- `Docs/Plugins.md`
- `Docs/Request-Building.md`
- `Docs/Clients.md`
- `Docs/Architecture.md`

Chinese:
- `Docs/zh/Getting-Started.md`
- `Docs/zh/Core-Types.md`
- `Docs/zh/Plugins.md`
- `Docs/zh/Request-Building.md`
- `Docs/zh/Clients.md`
- `Docs/zh/Architecture.md`

## Build & Test

```bash
swift build
swift test
```

# Moira

Moira is a lightweight networking layer built on Swift Concurrency.
It provides clear request descriptions, a predictable lifecycle, and pluggable behavior.

## Highlights

- Request description: `APIRequest` + `RequestPayload`
- Request building: `RequestBuilder`
- Plugins: Transform / Observer / Retry / ShortCircuit
- Decoder injection: `ResponseDecoder`
- Upload/download progress: `RequestTask.progress`

## Quick Example

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

let user: User = try await provider.request(UserAPI.profile(id: "123"))
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

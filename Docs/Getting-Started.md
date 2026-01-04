# Moira Getting Started

Moira is a lightweight networking layer built on Swift Concurrency.
It focuses on clear request descriptions, a predictable pipeline, and pluggable behavior.

## Define an API

```swift
import Moira

enum UserAPI: APIRequest {
    case profile(id: String)
    case updateProfile(id: String, payload: UpdateProfile)

    var path: String {
        switch self {
        case .profile(let id):
            return "/users/\(id)"
        case .updateProfile(let id, _):
            return "/users/\(id)"
        }
    }

    var method: RequestMethod {
        switch self {
        case .profile:
            return .get
        case .updateProfile:
            return .patch
        }
    }

    var payload: RequestPayload {
        switch self {
        case .profile:
            return RequestPayload()
        case .updateProfile(_, let body):
            return RequestPayload().withJSON(body)
        }
    }
}

struct UpdateProfile: Encodable, Sendable {
    let name: String
}
```

## Create a provider

```swift
let baseURL = URL(string: "https://api.example.com")!
let builder = RequestBuilder(baseURL: baseURL)
let provider = APIProvider(client: AlamofireClient(), builder: builder)
```

## Decode a response

```swift
let user: User = try await provider.request(
    UserAPI.profile(id: "123"),
    decoder: JSONDecoder()
)
```

## Access raw responses

```swift
let response = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## Upload with progress

```swift
let data = Data("payload".utf8)
let request = UploadAPI.data(data)
let task = try await provider.requestTask(request)

if let progress = task.progress {
    Task {
        for await update in progress {
            print(update.completedBytes)
        }
    }
}

let response = try await task.response()
```

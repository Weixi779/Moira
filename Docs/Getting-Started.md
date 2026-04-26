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
            return .json(body)
        }
    }

    var execution: RequestExecution { .request }
}

struct UpdateProfile: Encodable, Sendable {
    let name: String
}
```

## Create a provider

```swift
let baseURL = URL(string: "https://api.example.com")!
let builder = URLRequestBuilder(baseURL: baseURL)
let provider = APIProvider(client: URLSessionClient(), builder: builder)
```

## Configure retry

```swift
struct DefaultRetryStrategy: RetryStrategy {
    func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision {
        snapshot.retryCount == 0 ? .retry(.rebuildRequest) : .doNotRetry
    }
}

let provider = APIProvider(
    client: URLSessionClient(),
    builder: builder,
    retryStrategy: DefaultRetryStrategy()
)
```

## Decode a response

```swift
let user: User = try await provider.request(UserAPI.profile(id: "123"))
```

## Access raw responses

```swift
let response = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## Upload with progress

```swift
struct UploadRequest: APIRequest {
    let path = "/upload"
    let method: RequestMethod = .post
    let payload = RequestPayload()
    let execution: RequestExecution

    init(source: UploadSource) {
        self.execution = .upload(source)
    }
}

let data = Data("payload".utf8)
let request = UploadRequest(source: .data(data))
let task = try await provider.uploadTask(request)

Task {
    for await update in task.progress {
        print(update.completedBytes)
    }
}

let response = try await task.response()
```

# Moira 快速开始

Moira 是一个基于 Swift Concurrency 的轻量网络层。
它强调清晰的请求描述、可预测的生命周期和可插拔的行为。

## 定义 API

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

## 创建 Provider

```swift
let baseURL = URL(string: "https://api.example.com")!
let builder = URLRequestBuilder(baseURL: baseURL)
let provider = APIProvider(client: URLSessionClient(), builder: builder)
```

## 配置重试

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

## 解码响应

```swift
let user: User = try await provider.request(UserAPI.profile(id: "123"))
```

## 获取原始响应

```swift
let response = try await provider.request(UserAPI.profile(id: "123"))
print(response.statusCode)
print(response.data)
```

## 上传与进度

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

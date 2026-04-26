# 核心类型

本页列出 Moira 的核心公开类型与含义。

## APIRequest

```swift
public protocol APIRequest: Sendable {
    var path: String { get }
    var method: RequestMethod { get }
    var payload: RequestPayload { get }
    var execution: RequestExecution { get }

    var baseURL: URL? { get }
    var headers: [String: String]? { get }
    var timeout: TimeInterval { get }
}
```

默认值：
- `baseURL = nil`
- `headers = nil`
- `timeout = 60`
- `payload = RequestPayload()`

`path` 会被当作 endpoint path 追加到最终 baseURL 的 path 后面；前导 `/` 不会让它回退到 host 根路径。

注意：`execution` 没有默认值，每个遵循者必须显式声明 `.request` 或 `.upload(...)`。

## RequestExecution

```swift
public enum RequestExecution: Sendable {
    case request
    case upload(UploadSource)
}
```

决定请求是普通 HTTP 请求还是上传请求。Provider 根据此值进行派发。

## RequestMethod

```swift
public enum RequestMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}
```

## RequestPayload

```swift
public struct RequestPayload: Sendable {
    public enum Body: Sendable {
        case none
        case json(any JSONEncodable)
        case urlEncodedForm([URLQueryItem])
        case data(Data)
    }

    public var query: [URLQueryItem]
    public var body: Body
}
```

静态工厂：
- `.query(_:_:)` / `.queries(_:)`
- `.json(_:)` / `.formEncoded(_:)` / `.data(_:)`

链式调用（query 追加，body 覆盖）：
- `.query(_:_:)` / `.queries(_:)`
- `.json(_:)` / `.formEncoded(_:)` / `.data(_:)`

默认值：
- `query = []`
- `body = .none`

上传数据不属于 `RequestPayload.Body`，请使用 `execution: .upload(source)` 代替。

## JSONEncodable

```swift
public protocol JSONEncodable: Sendable {
    func encode(using encoder: JSONEncoder) throws -> Data
}
```

`RequestPayload.json(_:)` 可以直接接收常规的 `Encodable & Sendable` 值；大多数使用场景下不需要直接接触 `JSONEncodable`。

## UploadSource

```swift
public enum UploadSource: Sendable {
    case data(Data)
    case file(URL)
    case multipart([MultipartFormPart])
}
```

## MultipartFormPart

```swift
public struct MultipartFormPart: Sendable {
    public let name: String
    public let data: Data
    public let fileName: String?
    public let mimeType: String?
}
```

## APIResponse

原始响应数据的承载对象。

```swift
public struct APIResponse: Sendable {
    public let statusCode: Int
    public let data: Data
    public let headers: [String: String]
    public let response: HTTPURLResponse?
}
```

## ResponseDecoder

`APIProvider` 使用的解码接口。

```swift
public protocol ResponseDecoder: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: ResponseDecoder {}
```

## APIError

Moira 定义的错误。

```swift
public enum APIError: Error, Sendable {
    case requestBuildingFailed(String)
    case responseDecodingFailed(Error)
    case underlying(Error, response: APIResponse?)
    case invalidRequest(String)
    case capabilityNotSupported(String)
}
```

调用方不应假设 `APIProvider` 只会抛出 `APIError`。插件、response validation、自定义 client 抛出的错误可能会原样透出。Moira 会在框架自身产生的失败中显式抛出 `APIError`，例如非法请求模型、请求构建失败、typed decode 失败。第一方 client 会将传输层失败包装为 `APIError.underlying`，以便在可用时携带 `APIResponse`。

`invalidRequest` 在请求违反模型约束时抛出，例如上传请求同时携带非空 `payload.body`。

`capabilityNotSupported` 在当前配置的 client/provider 不支持被请求能力时抛出，例如 request-only client 上调用上传。

## APIProviding

请求执行的上层接口。

```swift
public protocol APIClient: Sendable {
    func request(_ request: URLRequest) async throws -> APIResponse
}

public protocol APIUploadClient: Sendable {
    func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse>
}

public protocol APIRequesting: Sendable {
    @discardableResult
    func request(_ target: any APIRequest) async throws -> APIResponse
    func request<T: Decodable>(_ target: any APIRequest) async throws -> T
}

public protocol APIUploading: Sendable {
    func uploadTask(_ target: any APIRequest) async throws -> UploadTask<APIResponse>
    func uploadTask<T: Decodable & Sendable>(_ target: any APIRequest) async throws -> UploadTask<T>
}

public protocol APIProviding: APIRequesting, APIUploading {}
```

`APIClient` 只表示普通请求能力。上传能力由 `APIUploadClient` 单独建模。`APIProvider.uploadTask` 需要当前配置的 client 支持 `APIUploadClient`；否则会抛出 `APIError.capabilityNotSupported`。

## UploadTask

上传专属任务类型，`progress` 非可空。

```swift
public final class UploadTask<T: Sendable>: Sendable {
    public let progress: AsyncStream<UploadProgress>
    public let response: @Sendable () async throws -> T
}
```

## UploadProgress

```swift
public struct UploadProgress: Sendable {
    public let completedBytes: Int64
    public let totalBytes: Int64?
}
```

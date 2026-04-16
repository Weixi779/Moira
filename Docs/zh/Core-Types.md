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

public struct AnyJSONEncodable<T: Encodable & Sendable>: JSONEncodable {
    public init(_ value: T)
}
```

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

请求流程对外暴露的错误。

```swift
public enum APIError: Error, Sendable {
    case requestBuildingFailed(String)
    case responseDecodingFailed(Error)
    case underlying(Error, response: APIResponse?)
    case invalidRequest(String)
}
```

`invalidRequest` 在请求违反模型约束时抛出，例如上传请求同时携带非空 `payload.body`。

## APIProviding

请求执行的上层接口。

```swift
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

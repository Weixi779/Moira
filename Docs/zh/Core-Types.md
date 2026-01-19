# 核心类型

本页列出 Moira 的核心公开类型与含义。

## APIRequest

```swift
public protocol APIRequest: Sendable {
    var path: String { get }
    var method: RequestMethod { get }
    var payload: RequestPayload { get }

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
        case upload(UploadSource)
    }

    public var query: [URLQueryItem]
    public var body: Body
}
```

便捷方法：
- `withJSON(_:)`
- `withURLEncodedForm(_:)`
- `withData(_:)`
- `withUpload(_:)`

默认值：
- `query = []`
- `body = .none`

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
    case underlying(Error)
}
```

## APIProviding

请求执行的上层接口。

```swift
public protocol APIProviding: Sendable {
    func request(_ target: any APIRequest) async throws
    func request<T: Decodable>(_ target: any APIRequest) async throws -> T
    func requestTask(_ target: any APIRequest) async throws -> RequestTask
}
```

## RequestTask

非上传/下载请求时，`progress` 为 `nil`。

```swift
public final class RequestTask: Sendable {
    public let progress: AsyncStream<RequestProgress>?
    public let response: @Sendable () async throws -> APIResponse
}
```

## RequestProgress

```swift
public struct RequestProgress: Sendable {
    public let completedBytes: Int64
    public let totalBytes: Int64?
}
```

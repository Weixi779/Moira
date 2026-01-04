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

## UploadSource

```swift
public enum UploadSource: Sendable {
    case data(Data)
    case file(URL)
    case multipart([MultipartFormPart])
}
```

## APIResponse

```swift
public struct APIResponse: Sendable {
    public let statusCode: Int
    public let data: Data
    public let headers: [String: String]
    public let response: HTTPURLResponse?
}
```

## ResponseDecoder

```swift
public protocol ResponseDecoder: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: ResponseDecoder {}
```

## APIError

```swift
public enum APIError: Error, Sendable {
    case requestBuildingFailed(String)
    case responseDecodingFailed(Error)
    case underlying(Error)
}
```

## APIProviding

```swift
public protocol APIProviding: Sendable {
    func request(_ target: any APIRequest) async throws -> APIResponse
    func request<T: Decodable>(_ target: any APIRequest, decoder: ResponseDecoder) async throws -> T
    func requestTask(_ target: any APIRequest) async throws -> RequestTask
}
```

## RequestTask

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

# Core Types

This file lists Moira's public types and their intent.

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

Defaults:
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

Convenience:
- `withJSON(_:)`
- `withURLEncodedForm(_:)`
- `withData(_:)`
- `withUpload(_:)`

Defaults:
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

Container for raw response data.

```swift
public struct APIResponse: Sendable {
    public let statusCode: Int
    public let data: Data
    public let headers: [String: String]
    public let response: HTTPURLResponse?
}
```

## ResponseDecoder

Decoder interface used by `APIProvider`.

```swift
public protocol ResponseDecoder: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: ResponseDecoder {}
```

## APIError

Errors surfaced by the request pipeline.

```swift
public enum APIError: Error, Sendable {
    case requestBuildingFailed(String)
    case responseDecodingFailed(Error)
    case underlying(Error)
}
```

## APIProviding

High-level interface for executing requests.

```swift
public protocol APIProviding: Sendable {
    func request(_ target: any APIRequest) async throws
    func request<T: Decodable>(_ target: any APIRequest) async throws -> T
    func requestTask(_ target: any APIRequest) async throws -> RequestTask<APIResponse>
    func requestTask<T: Decodable & Sendable>(_ target: any APIRequest) async throws -> RequestTask<T>
}
```

## RequestTask

`progress` is `nil` for non-upload/download requests.

```swift
public final class RequestTask<T: Sendable>: Sendable {
    public let progress: AsyncStream<RequestProgress>?
    public let response: @Sendable () async throws -> T
}
```

## RequestProgress

```swift
public struct RequestProgress: Sendable {
    public let completedBytes: Int64
    public let totalBytes: Int64?
}
```

# Core Types

This file lists Moira's public types and their intent.

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

Defaults:
- `baseURL = nil`
- `headers = nil`
- `timeout = 60`
- `payload = RequestPayload()`

`path` is an endpoint path appended to the resolved base URL path. A leading `/` does not reset to the host root.

Note: `execution` has no default value. Every conformer must declare `.request` or `.upload(...)` explicitly.

## RequestExecution

```swift
public enum RequestExecution: Sendable {
    case request
    case upload(UploadSource)
}
```

Determines whether the request executes as a regular HTTP request or an upload. The provider dispatches based on this value.

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

Convenience:
- `withJSON(_:)`
- `withURLEncodedForm(_:)`
- `withData(_:)`

Defaults:
- `query = []`
- `body = .none`

Upload payloads are not part of `RequestPayload.Body`. Use `execution: .upload(source)` instead.

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
    case underlying(Error, response: APIResponse?)
    case invalidRequest(String)
}
```

`invalidRequest` is thrown when a request violates model constraints, such as an upload request with a non-empty `payload.body`.

## APIProviding

High-level interface for executing requests.

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

Upload-specific task with non-optional progress.

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

import Foundation

/// Describes query items and body payload for a request.
public struct RequestPayload: Sendable {
    /// Body payload variants supported by the builder and clients.
    public enum Body: Sendable {
        /// No request body.
        case none
        /// JSON body encoded with a `JSONEncoder`.
        case json(any JSONEncodable)
        /// URL-encoded form body using query items.
        case urlEncodedForm([URLQueryItem])
        /// Raw body data.
        case data(Data)
        /// Upload payload handled by the client.
        case upload(UploadSource)
    }

    /// Query items appended to the request URL.
    public var query: [URLQueryItem]
    /// Body payload for the request.
    public var body: Body

    public init(query: [URLQueryItem] = [], body: Body = .none) {
        self.query = query
        self.body = body
    }

    /// Returns a payload with an appended query item.
    public func appendingQueryItem(_ item: URLQueryItem) -> Self {
        var copy = self
        copy.query.append(item)
        return copy
    }

    /// Returns a payload with appended query items.
    public func appendingQueryItems(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.query.append(contentsOf: items)
        return copy
    }

    /// Returns a payload with a query item replaced by name.
    public func replacingQueryItem(_ item: URLQueryItem) -> Self {
        var copy = self
        copy.query.removeAll { $0.name == item.name }
        copy.query.append(item)
        return copy
    }

    /// Returns a payload with query items replaced.
    public func replacingQueryItems(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.query = items
        return copy
    }

    /// Returns a payload with a JSON body.
    public func withJSON<T: Encodable & Sendable>(_ body: T) -> Self {
        var copy = self
        copy.body = .json(AnyJSONEncodable(body))
        return copy
    }

    /// Returns a payload with a URL-encoded form body.
    public func withURLEncodedForm(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.body = .urlEncodedForm(items)
        return copy
    }

    /// Returns a payload with raw body data.
    public func withData(_ data: Data) -> Self {
        var copy = self
        copy.body = .data(data)
        return copy
    }

    /// Returns a payload with an upload source.
    public func withUpload(_ source: UploadSource) -> Self {
        var copy = self
        copy.body = .upload(source)
        return copy
    }
}

/// Upload payload definition consumed by clients.
public enum UploadSource: Sendable {
    /// Upload raw data.
    case data(Data)
    /// Upload from a file URL.
    case file(URL)
    /// Upload multipart form parts.
    case multipart([MultipartFormPart])
}

/// A single multipart form field.
public struct MultipartFormPart: Sendable {
    /// Field name in the multipart form.
    public let name: String
    /// Raw field data.
    public let data: Data
    /// Optional file name for file parts.
    public let fileName: String?
    /// Optional MIME type for the part.
    public let mimeType: String?

    public init(
        name: String,
        data: Data,
        fileName: String? = nil,
        mimeType: String? = nil
    ) {
        self.name = name
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

import Foundation

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

    public init(query: [URLQueryItem] = [], body: Body = .none) {
        self.query = query
        self.body = body
    }

    public func appendingQueryItem(_ item: URLQueryItem) -> Self {
        var copy = self
        copy.query.append(item)
        return copy
    }

    public func appendingQueryItems(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.query.append(contentsOf: items)
        return copy
    }

    public func replacingQueryItem(_ item: URLQueryItem) -> Self {
        var copy = self
        copy.query.removeAll { $0.name == item.name }
        copy.query.append(item)
        return copy
    }

    public func replacingQueryItems(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.query = items
        return copy
    }

    public func withJSON<T: Encodable & Sendable>(_ body: T) -> Self {
        var copy = self
        copy.body = .json(AnyJSONEncodable(body))
        return copy
    }

    public func withURLEncodedForm(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.body = .urlEncodedForm(items)
        return copy
    }

    public func withData(_ data: Data) -> Self {
        var copy = self
        copy.body = .data(data)
        return copy
    }

    public func withUpload(_ source: UploadSource) -> Self {
        var copy = self
        copy.body = .upload(source)
        return copy
    }
}

public enum UploadSource: Sendable {
    case data(Data)
    case file(URL)
    case multipart([MultipartFormPart])
}

public struct MultipartFormPart: Sendable {
    public let name: String
    public let data: Data
    public let fileName: String?
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

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
    }

    /// Query items appended to the request URL.
    public var query: [URLQueryItem]
    /// Body payload for the request.
    public var body: Body

    public init(query: [URLQueryItem] = [], body: Body = .none) {
        self.query = query
        self.body = body
    }

    // MARK: - Static Factories

    /// Creates a payload with a single query item.
    public static func query(_ name: String, _ value: String?) -> Self {
        Self(query: [URLQueryItem(name: name, value: value)])
    }

    /// Creates a payload with multiple query items.
    public static func queries(_ items: [URLQueryItem]) -> Self {
        Self(query: items)
    }

    /// Creates a payload with a JSON body.
    public static func json(_ body: some Encodable & Sendable) -> Self {
        Self(body: .json(AnyJSONEncodable(body)))
    }

    /// Creates a payload with a URL-encoded form body.
    public static func formEncoded(_ items: [URLQueryItem]) -> Self {
        Self(body: .urlEncodedForm(items))
    }

    /// Creates a payload with raw body data.
    public static func data(_ data: Data) -> Self {
        Self(body: .data(data))
    }

    // MARK: - Chaining (Query — always appends)

    /// Returns a payload with an appended query item.
    public func query(_ name: String, _ value: String?) -> Self {
        var copy = self
        copy.query.append(URLQueryItem(name: name, value: value))
        return copy
    }

    /// Returns a payload with appended query items.
    public func queries(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.query.append(contentsOf: items)
        return copy
    }

    // MARK: - Chaining (Body — sets/overrides)

    /// Returns a payload with a JSON body.
    public func json(_ body: some Encodable & Sendable) -> Self {
        var copy = self
        copy.body = .json(AnyJSONEncodable(body))
        return copy
    }

    /// Returns a payload with a URL-encoded form body.
    public func formEncoded(_ items: [URLQueryItem]) -> Self {
        var copy = self
        copy.body = .urlEncodedForm(items)
        return copy
    }

    /// Returns a payload with raw body data.
    public func data(_ data: Data) -> Self {
        var copy = self
        copy.body = .data(data)
        return copy
    }
}

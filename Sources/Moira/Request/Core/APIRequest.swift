import Foundation

/// Describes a request that can be built into a `URLRequest`.
public protocol APIRequest: Sendable {
    /// Endpoint path appended to the base URL path.
    var path: String { get }
    /// HTTP method for the request.
    var method: RequestMethod { get }
    /// Query items and body payload.
    var payload: RequestPayload { get }
    /// Determines whether this request is a regular request or an upload.
    var execution: RequestExecution { get }

    /// Optional override for the provider's base URL.
    var baseURL: URL? { get }
    /// Additional headers to include.
    var headers: [String: String]? { get }
    /// Timeout interval in seconds.
    var timeout: TimeInterval { get }
}

public extension APIRequest {
    /// Defaults to `nil`, so the provider base URL is used.
    var baseURL: URL? {
        nil
    }

    /// Defaults to `nil`, so no extra headers are applied.
    var headers: [String: String]? {
        nil
    }

    /// Defaults to 60 seconds.
    var timeout: TimeInterval {
        60
    }

    /// Defaults to an empty payload.
    var payload: RequestPayload {
        .init()
    }
}

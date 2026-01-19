import Foundation

/// Container for the raw HTTP response data.
public struct APIResponse: Sendable {
    /// HTTP status code.
    public let statusCode: Int
    /// Raw response body.
    public let data: Data
    /// Response headers.
    public let headers: [String: String]
    /// Original `HTTPURLResponse`, when available.
    public let response: HTTPURLResponse?

    public init(
        statusCode: Int,
        data: Data,
        headers: [String: String],
        response: HTTPURLResponse? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
        self.response = response
    }
}

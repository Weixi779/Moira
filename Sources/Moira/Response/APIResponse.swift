import Foundation

public struct APIResponse: Sendable {
    public let statusCode: Int
    public let data: Data
    public let headers: [String: String]
    public let request: URLRequest?
    public let response: HTTPURLResponse?

    public init(
        statusCode: Int,
        data: Data,
        headers: [String: String],
        request: URLRequest? = nil,
        response: HTTPURLResponse? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
        self.request = request
        self.response = response
    }
}

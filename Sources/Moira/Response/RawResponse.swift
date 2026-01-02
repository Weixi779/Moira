import Foundation

public struct RawResponse: Sendable {
    public let data: Data
    public let response: HTTPURLResponse?

    public init(data: Data, response: HTTPURLResponse?) {
        self.data = data
        self.response = response
    }
}

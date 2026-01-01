import Foundation

public protocol APIRequest: Sendable {
    var path: String { get }
    var method: RequestMethod { get }
    var payload: RequestPayload { get }

    var baseURL: URL? { get }
    var headers: [String: String]? { get }
    var timeout: TimeInterval { get }
}

public extension APIRequest {
    var baseURL: URL? { nil }
    var headers: [String: String]? { nil }
    var timeout: TimeInterval { 60 }
    var payload: RequestPayload { .init() }
}

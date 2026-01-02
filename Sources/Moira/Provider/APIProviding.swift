import Foundation

public protocol APIProviding: Sendable {
    func request(_ target: any APIRequest) async throws -> APIResponse
    func request<T: Decodable>(_ target: any APIRequest, decoder: ResponseDecoder) async throws -> T
    func requestTask(_ target: any APIRequest) async throws -> RequestTask
}

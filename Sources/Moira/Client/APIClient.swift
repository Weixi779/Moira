import Foundation

public protocol APIClient {
    func request(_ request: URLRequest) async throws -> APIResponse
    func upload(_ request: URLRequest, source: UploadSource) throws -> RequestTask
    func download(_ request: URLRequest) throws -> RequestTask
}

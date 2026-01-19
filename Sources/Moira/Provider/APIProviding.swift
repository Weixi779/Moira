import Foundation

/// High-level request interface used by application code.
public protocol APIProviding: Sendable {
    /// Executes a request, ignoring the response body.
    func request(_ target: any APIRequest) async throws
    /// Executes a request and decodes the response body.
    func request<T: Decodable>(_ target: any APIRequest) async throws -> T
    /// Returns a task for uploads/downloads with progress support.
    func requestTask(_ target: any APIRequest) async throws -> RequestTask
}

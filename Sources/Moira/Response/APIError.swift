import Foundation

/// Errors surfaced by the Moira request pipeline.
public enum APIError: Error, Sendable {
    /// Request building failed with an invalid path or configuration.
    case requestBuildingFailed(String)
    /// Response decoding failed with the provided decoder.
    case responseDecodingFailed(Error)
    /// Wraps errors thrown by clients or plugins.
    case underlying(Error, response: APIResponse?)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .requestBuildingFailed(let reason):
            if reason.isEmpty { return "Request building failed." }
            return "Request building failed: \(reason)"
        case .responseDecodingFailed(let error):
            return "Response decoding failed: \(error.localizedDescription)"
        case .underlying(let error, _):
            return "Request failed due to an underlying error: \(error.localizedDescription)"
        }
    }
}

import Foundation

/// Errors surfaced by the Moira request pipeline.
public enum APIError: Error, Sendable {
    /// Request building failed with an invalid path or configuration.
    case requestBuildingFailed(String)
    /// Response decoding failed with the provided decoder.
    case responseDecodingFailed(Error)
    /// Wraps errors thrown by clients or plugins.
    case underlying(Error, response: APIResponse?)
    /// Request violates a model constraint (e.g. upload with non-empty body).
    case invalidRequest(String)
    /// Requested capability is not supported by the configured client/provider.
    case capabilityNotSupported(String)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .requestBuildingFailed(reason):
            if reason.isEmpty { return "Request building failed." }
            return "Request building failed: \(reason)"
        case let .responseDecodingFailed(error):
            return "Response decoding failed: \(error.localizedDescription)"
        case let .underlying(error, _):
            return "Request failed due to an underlying error: \(error.localizedDescription)"
        case let .invalidRequest(reason):
            if reason.isEmpty { return "Invalid request." }
            return "Invalid request: \(reason)"
        case let .capabilityNotSupported(reason):
            if reason.isEmpty { return "Capability not supported." }
            return "Capability not supported: \(reason)"
        }
    }
}

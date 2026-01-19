/// Errors surfaced by the Moira request pipeline.
public enum APIError: Error, Sendable {
    /// Request building failed with an invalid path or configuration.
    case requestBuildingFailed(String)
    /// Response decoding failed with the provided decoder.
    case responseDecodingFailed(Error)
    /// Wraps errors thrown by clients or plugins.
    case underlying(Error)
}

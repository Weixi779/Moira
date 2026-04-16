/// Execution mode for a request.
public enum RequestExecution: Sendable {
    /// A regular HTTP request.
    case request
    /// An upload request with the given source.
    case upload(UploadSource)
}

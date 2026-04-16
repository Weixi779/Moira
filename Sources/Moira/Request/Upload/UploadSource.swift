import Foundation

/// Upload payload definition consumed by clients.
public enum UploadSource: Sendable {
    /// Upload raw data.
    case data(Data)
    /// Upload from a file URL.
    case file(URL)
    /// Upload multipart form parts.
    case multipart([MultipartFormPart])
}

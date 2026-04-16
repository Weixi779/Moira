import Foundation

/// A single multipart form field.
public struct MultipartFormPart: Sendable {
    /// Field name in the multipart form.
    public let name: String
    /// Raw field data.
    public let data: Data
    /// Optional file name for file parts.
    public let fileName: String?
    /// Optional MIME type for the part.
    public let mimeType: String?

    public init(
        name: String,
        data: Data,
        fileName: String? = nil,
        mimeType: String? = nil
    ) {
        self.name = name
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

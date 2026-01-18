import Foundation

/// Progress information for upload or download tasks.
public struct RequestProgress: Sendable {
    /// Bytes completed so far.
    public let completedBytes: Int64
    /// Total bytes expected, if known.
    public let totalBytes: Int64?

    public init(completedBytes: Int64, totalBytes: Int64?) {
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }
}

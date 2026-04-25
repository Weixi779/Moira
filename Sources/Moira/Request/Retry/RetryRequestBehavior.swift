/// Defines how the next retry attempt obtains its URLRequest.
public enum RetryRequestBehavior: Sendable {
    case reuseRequest
    case rebuildRequest
}

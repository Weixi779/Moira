/// Validates raw responses without modifying them.
public protocol ResponseValidationPlugin: RequestPlugin {
    /// Throws when the response is not acceptable.
    func validateResponse(_ response: APIResponse) async throws
}

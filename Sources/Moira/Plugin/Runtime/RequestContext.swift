import Foundation

/// Whether a prepared request executes as a regular request or an upload.
public enum RequestExecutionKind: Sendable, Equatable {
    case request
    case upload
}

extension RequestExecutionKind {
    init(execution: RequestExecution) {
        if case .upload = execution {
            self = .upload
        } else {
            self = .request
        }
    }
}

/// Immutable request lifecycle state observed by plugins and retry strategies.
///
/// `RequestSnapshot` is an immutable projection of internal request state. It is
/// marked unchecked because it carries existential values such as `any APIRequest`
/// and `Error?`, but Moira only exposes it as a read-only value.
public struct RequestSnapshot: @unchecked Sendable {
    /// Snapshot identifier matching the request.
    public let id: UUID
    /// Original API request target, before transform plugins prepare it.
    public let target: any APIRequest
    /// Execution kind resolved from the prepared target.
    public let executionKind: RequestExecutionKind
    /// Timestamp when this transport attempt is about to be sent.
    public let attemptStartedAt: Date
    /// Built request if available.
    public let request: URLRequest?
    /// Response if available.
    public let response: APIResponse?
    /// Error if available.
    public let error: Error?
    /// Retry count at snapshot time.
    public let retryCount: Int
}

/// Request-scoped state shared across the provider execution flow.
actor RequestContext {
    private var requestState: RequestState
    private var attemptState: AttemptState

    init(target: any APIRequest) {
        requestState = RequestState(target: target)
        attemptState = AttemptState()
    }

    func originalTarget() -> any APIRequest {
        requestState.target
    }

    func setPreparedTargetAndRequest(
        _ preparedTarget: any APIRequest,
        request: URLRequest
    ) {
        requestState.preparedTarget = preparedTarget
        requestState.request = request
        requestState.executionKind = RequestExecutionKind(execution: preparedTarget.execution)
    }

    func currentPreparedTarget() throws -> any APIRequest {
        guard let preparedTarget = requestState.preparedTarget else {
            throw APIError.invalidRequest("Request has not been prepared.")
        }
        return preparedTarget
    }

    func currentURLRequest() throws -> URLRequest {
        guard let request = requestState.request else {
            throw APIError.invalidRequest("URLRequest has not been prepared.")
        }
        return request
    }

    func beginRetryPreparation(rebuildsRequest: Bool) {
        attemptState.retryCount += 1
        attemptState.response = nil
        attemptState.error = nil

        if rebuildsRequest {
            requestState.preparedTarget = nil
            requestState.request = nil
            requestState.executionKind = RequestExecutionKind(execution: requestState.target.execution)
        }
    }

    func beginSendingAttempt() {
        attemptState.attemptStartedAt = Date()
        attemptState.response = nil
        attemptState.error = nil
    }

    func recordResponse(_ response: APIResponse) {
        attemptState.response = response
    }

    func recordFailure(_ error: Error) {
        attemptState.error = error
        if let response = Self.response(from: error) {
            attemptState.response = response
        }
    }

    func snapshot() -> RequestSnapshot {
        RequestSnapshot(
            id: requestState.id,
            target: requestState.target,
            executionKind: requestState.executionKind,
            attemptStartedAt: attemptState.attemptStartedAt,
            request: requestState.request,
            response: attemptState.response,
            error: attemptState.error,
            retryCount: attemptState.retryCount
        )
    }
}

private struct RequestState: @unchecked Sendable {
    let id: UUID
    let target: any APIRequest
    var preparedTarget: (any APIRequest)?
    var request: URLRequest?
    var executionKind: RequestExecutionKind

    init(target: any APIRequest) {
        id = UUID()
        self.target = target
        executionKind = RequestExecutionKind(execution: target.execution)
    }
}

private struct AttemptState: @unchecked Sendable {
    var attemptStartedAt: Date
    var response: APIResponse?
    var error: Error?
    var retryCount: Int

    init() {
        attemptStartedAt = Date()
        retryCount = 0
    }
}

private extension RequestContext {
    static func response(from error: Error) -> APIResponse? {
        guard case let APIError.underlying(_, response) = error else {
            return nil
        }
        return response
    }
}

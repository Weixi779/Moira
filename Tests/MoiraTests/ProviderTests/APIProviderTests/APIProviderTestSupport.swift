import Foundation
@testable import Moira

enum APIProviderTestSupport {
    static let baseURL = URL(string: "https://unit-test.invalid")!

    static func makeBuilder() -> URLRequestBuilder {
        URLRequestBuilder(baseURL: baseURL)
    }

    final class CountingBuilder: URLRequestBuilding, @unchecked Sendable {
        private let builder = URLRequestBuilder(baseURL: APIProviderTestSupport.baseURL)
        private(set) var buildCount = 0

        func build(_ target: any APIRequest) throws -> URLRequest {
            buildCount += 1
            return try builder.build(target)
        }
    }

    static func makeResponse(statusCode: Int = 200, data: Data = Data()) -> APIResponse {
        APIResponse(statusCode: statusCode, data: data, headers: [:])
    }

    struct SimpleRequest: APIRequest {
        let path: String
        let method: RequestMethod
        let payload: RequestPayload
        let execution: RequestExecution
        let baseURL: URL?
        let headers: [String: String]?
        let timeout: TimeInterval

        init(
            path: String = "/test",
            method: RequestMethod = .get,
            payload: RequestPayload = .init(),
            execution: RequestExecution = .request,
            baseURL: URL? = nil,
            headers: [String: String]? = nil,
            timeout: TimeInterval = 60
        ) {
            self.path = path
            self.method = method
            self.payload = payload
            self.execution = execution
            self.baseURL = baseURL
            self.headers = headers
            self.timeout = timeout
        }
    }

    final class MockClient: APIClient, APIUploadClient, @unchecked Sendable {
        private(set) var requestCount = 0
        private(set) var uploadCount = 0
        private(set) var uploadedSource: UploadSource?
        private let handler: @Sendable (URLRequest) async throws -> APIResponse

        init(handler: @escaping @Sendable (URLRequest) async throws -> APIResponse) {
            self.handler = handler
        }

        func request(_ request: URLRequest) async throws -> APIResponse {
            requestCount += 1
            return try await handler(request)
        }

        func upload(_ request: URLRequest, source: UploadSource) throws -> UploadTask<APIResponse> {
            uploadCount += 1
            uploadedSource = source
            let handler = self.handler
            let (stream, continuation) = AsyncStream<UploadProgress>.makeStream()
            continuation.finish()
            return UploadTask(progress: stream) {
                try await handler(request)
            }
        }
    }

    struct RequestOnlyClient: APIClient {
        let handler: @Sendable (URLRequest) async throws -> APIResponse

        func request(_ request: URLRequest) async throws -> APIResponse {
            try await handler(request)
        }
    }

    actor EventLog {
        private var events: [String] = []

        func add(_ event: String) {
            events.append(event)
        }

        func all() -> [String] {
            events
        }
    }

    struct ObserverProbe: ObserverPlugin {
        let log: EventLog

        func willSend(snapshot: RequestSnapshot) async {
            await log.add("willSend")
        }

        func didReceive(snapshot: RequestSnapshot) async {
            await log.add("didReceive")
        }

        func didFail(snapshot: RequestSnapshot) async {
            await log.add("didFail")
        }
    }

    struct SnapshotObserverProbe: ObserverPlugin {
        let log: EventLog?
        let capture: SnapshotCapture

        init(log: EventLog? = nil, capture: SnapshotCapture) {
            self.log = log
            self.capture = capture
        }

        func willSend(snapshot: RequestSnapshot) async {
            await log?.add("willSend")
            await capture.add("willSend", snapshot: snapshot)
        }

        func didReceive(snapshot: RequestSnapshot) async {
            await log?.add("didReceive")
            await capture.add("didReceive", snapshot: snapshot)
        }

        func didFail(snapshot: RequestSnapshot) async {
            await log?.add("didFail")
            await capture.add("didFail", snapshot: snapshot)
        }
    }

    actor SnapshotCapture {
        private var snapshots: [String: [RequestSnapshot]] = [:]

        func add(_ event: String, snapshot: RequestSnapshot) {
            snapshots[event, default: []].append(snapshot)
        }

        func all(_ event: String) -> [RequestSnapshot] {
            snapshots[event] ?? []
        }
    }

    actor ResponseCapture {
        private var response: APIResponse?

        func set(_ response: APIResponse?) {
            self.response = response
        }

        func get() -> APIResponse? {
            response
        }
    }

    struct ResponseCaptureProbe: ObserverPlugin {
        let capture: ResponseCapture

        func willSend(snapshot: RequestSnapshot) async {}

        func didReceive(snapshot: RequestSnapshot) async {}

        func didFail(snapshot: RequestSnapshot) async {
            await capture.set(snapshot.response)
        }
    }

    struct RetryProbe: RetryStrategy {
        let log: EventLog
        let decision: RetryDecision

        func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision {
            await log.add("shouldRetry")
            return decision
        }

        func willRetry(snapshot: RequestSnapshot, error: Error, decision: RetryDecision) async {
            await log.add("willRetry")
        }
    }

    struct SnapshotRetryProbe: RetryStrategy {
        let log: EventLog
        let capture: SnapshotCapture
        let decision: RetryDecision

        func shouldRetry(snapshot: RequestSnapshot, error: Error) async -> RetryDecision {
            await log.add("shouldRetry")
            await capture.add("shouldRetry", snapshot: snapshot)
            return decision
        }

        func willRetry(snapshot: RequestSnapshot, error: Error, decision: RetryDecision) async {
            await log.add("willRetry")
            await capture.add("willRetry", snapshot: snapshot)
        }
    }

    struct ThrowingDecoder: ResponseDecoder {
        func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            throw APIProviderTestSupport.TestError.decodingFailed
        }
    }

    struct ThrowingResponseValidationProbe: ResponseValidationPlugin {
        let log: EventLog?

        init(log: EventLog? = nil) {
            self.log = log
        }

        func validateResponse(_ response: APIResponse) async throws {
            await log?.add("validate")
            throw APIProviderTestSupport.TestError.sample
        }
    }

    struct ThrowingAdaptProbe: TransformPlugin {
        func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
            request
        }

        func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
            throw APIProviderTestSupport.TestError.sample
        }
    }

    actor ThrowingSecondAdaptProbe: TransformPlugin {
        let error: TestError
        private var adaptCount = 0

        init(error: TestError = .sample) {
            self.error = error
        }

        func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
            request
        }

        func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
            defer { adaptCount += 1 }
            if adaptCount == 1 {
                throw error
            }
            return request
        }
    }

    struct ExecutionTransformPlugin: TransformPlugin {
        let execution: RequestExecution

        func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
            PreparedRequest(base: request, execution: execution)
        }

        func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
            request
        }
    }

    struct PreparedRequest: APIRequest {
        let path: String
        let method: RequestMethod
        let payload: RequestPayload
        let execution: RequestExecution
        let baseURL: URL?
        let headers: [String: String]?
        let timeout: TimeInterval

        init(base: any APIRequest, execution: RequestExecution) {
            self.path = base.path
            self.method = base.method
            self.payload = base.payload
            self.execution = execution
            self.baseURL = base.baseURL
            self.headers = base.headers
            self.timeout = base.timeout
        }
    }

    actor AttemptCounter {
        private var value = 0

        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }

    enum TestError: Error, Equatable {
        case sample
        case decodingFailed
        case unimplemented
    }

    actor CountingTransformPlugin: TransformPlugin {
        private var prepareCount = 0
        private var adaptCount = 0

        func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
            prepareCount += 1
            return request
        }

        func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
            adaptCount += 1
            return request
        }

        func counts() -> (prepare: Int, adapt: Int) {
            (prepareCount, adaptCount)
        }
    }

    actor CountingResponseValidationPlugin: ResponseValidationPlugin {
        private var validationCount = 0

        func validateResponse(_ response: APIResponse) async throws {
            validationCount += 1
        }

        func count() -> Int {
            validationCount
        }
    }

    actor ThrowingOnceResponseValidationPlugin: ResponseValidationPlugin {
        private var validationCount = 0

        func validateResponse(_ response: APIResponse) async throws {
            defer { validationCount += 1 }
            if validationCount == 0 {
                throw APIProviderTestSupport.TestError.sample
            }
        }

        func count() -> Int {
            validationCount
        }
    }

    actor ExecutionKindCapture {
        private var kind: RequestExecutionKind?

        func set(_ kind: RequestExecutionKind) {
            self.kind = kind
        }

        func get() -> RequestExecutionKind? {
            kind
        }
    }

    struct ExecutionKindProbe: ObserverPlugin {
        let capture: ExecutionKindCapture

        func willSend(snapshot: RequestSnapshot) async {
            await capture.set(snapshot.executionKind)
        }

        func didReceive(snapshot: RequestSnapshot) async {}
        func didFail(snapshot: RequestSnapshot) async {}
    }

    struct EmptyResponse: Decodable {}
}

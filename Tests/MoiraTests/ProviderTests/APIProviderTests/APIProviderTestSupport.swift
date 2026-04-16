import Foundation
@testable import Moira

enum APIProviderTestSupport {
    static let baseURL = URL(string: "https://unit-test.invalid")!

    static func makeBuilder() -> RequestBuilder {
        RequestBuilder(baseURL: baseURL)
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

    final class MockClient: APIClient {
        private(set) var requestCount = 0
        private(set) var uploadCount = 0
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
            let handler = self.handler
            let (stream, continuation) = AsyncStream<UploadProgress>.makeStream()
            continuation.finish()
            return UploadTask(progress: stream) {
                try await handler(request)
            }
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

        func willSend(snapshot: RequestContext.Snapshot) async {
            await log.add("willSend")
        }

        func didReceive(snapshot: RequestContext.Snapshot) async {
            await log.add("didReceive")
        }

        func didFail(snapshot: RequestContext.Snapshot) async {
            await log.add("didFail")
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

        func willSend(snapshot: RequestContext.Snapshot) async {}

        func didReceive(snapshot: RequestContext.Snapshot) async {}

        func didFail(snapshot: RequestContext.Snapshot) async {
            await capture.set(snapshot.response)
        }
    }

    struct RetryProbe: RetryPlugin {
        let log: EventLog
        let decision: RetryDecision
        let policy: RetryPolicy

        func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
            await log.add("shouldRetry")
            return decision
        }

        func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async {
            await log.add("willRetry")
        }
    }

    struct ShortCircuitProbe: ShortCircuitPlugin {
        let decision: ShortCircuitDecision

        func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision {
            decision
        }
    }

    struct RetryAwareShortCircuitProbe: ShortCircuitPlugin {
        let response: APIResponse

        func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision {
            if snapshot.retryCount > 0 {
                return .hitResult(response, source: "retry")
            }
            return .miss
        }
    }

    struct ThrowingDecoder: ResponseDecoder {
        func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            throw APIProviderTestSupport.TestError.decodingFailed
        }
    }

    struct ThrowingTransformProbe: TransformPlugin {
        func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
            request
        }

        func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
            request
        }

        func processResponse(_ response: APIResponse) async throws -> APIResponse {
            throw APIProviderTestSupport.TestError.sample
        }
    }

    actor AttemptCounter {
        private var value = 0

        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }

    enum TestError: Error {
        case sample
        case decodingFailed
        case unimplemented
    }

    actor CountingTransformPlugin: TransformPlugin {
        private var prepareCount = 0
        private var adaptCount = 0
        private var processCount = 0

        func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
            prepareCount += 1
            return request
        }

        func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
            adaptCount += 1
            return request
        }

        func processResponse(_ response: APIResponse) async throws -> APIResponse {
            processCount += 1
            return response
        }

        func counts() -> (prepare: Int, adapt: Int, process: Int) {
            (prepareCount, adaptCount, processCount)
        }
    }

    actor ExecutionKindCapture {
        private var kind: RequestContext.ExecutionKind?

        func set(_ kind: RequestContext.ExecutionKind) {
            self.kind = kind
        }

        func get() -> RequestContext.ExecutionKind? {
            kind
        }
    }

    struct ExecutionKindProbe: ObserverPlugin {
        let capture: ExecutionKindCapture

        func willSend(snapshot: RequestContext.Snapshot) async {
            await capture.set(snapshot.executionKind)
        }

        func didReceive(snapshot: RequestContext.Snapshot) async {}
        func didFail(snapshot: RequestContext.Snapshot) async {}
    }

    struct EmptyResponse: Decodable {}
}

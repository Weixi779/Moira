import Foundation
import Testing
@testable import Moira

private struct SimpleRequest: APIRequest {
    let path: String
    let method: RequestMethod
    let payload: RequestPayload
    let baseURL: URL?
    let headers: [String: String]?
    let timeout: TimeInterval

    init(
        path: String = "/test",
        method: RequestMethod = .get,
        payload: RequestPayload = .init(),
        baseURL: URL? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) {
        self.path = path
        self.method = method
        self.payload = payload
        self.baseURL = baseURL
        self.headers = headers
        self.timeout = timeout
    }
}

private final class MockClient: APIClient {
    private(set) var requestCount = 0
    private let handler: @Sendable (URLRequest) async throws -> APIResponse

    init(handler: @escaping @Sendable (URLRequest) async throws -> APIResponse) {
        self.handler = handler
    }

    func request(_ request: URLRequest) async throws -> APIResponse {
        requestCount += 1
        return try await handler(request)
    }

    func upload(_ request: URLRequest, source: UploadSource) throws -> RequestTask {
        throw TestError.unimplemented
    }

    func download(_ request: URLRequest) throws -> RequestTask {
        throw TestError.unimplemented
    }
}

private actor EventLog {
    private var events: [String] = []

    func add(_ event: String) {
        events.append(event)
    }

    func all() -> [String] {
        events
    }
}

private struct ObserverProbe: ObserverPlugin {
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

private struct RetryProbe: RetryPlugin {
    let log: EventLog
    let decision: RetryDecision

    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        await log.add("shouldRetry")
        return decision
    }

    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async {
        await log.add("willRetry")
    }
}

private struct ShortCircuitProbe: ShortCircuitPlugin {
    let decision: ShortCircuitDecision

    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision {
        decision
    }
}

private struct ThrowingDecoder: ResponseDecoder, Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        throw TestError.decodingFailed
    }
}

private actor AttemptCounter {
    private var value = 0

    func next() -> Int {
        defer { value += 1 }
        return value
    }
}

private enum TestError: Error {
    case sample
    case decodingFailed
    case unimplemented
}

private func makeResponse(statusCode: Int = 200, data: Data = Data()) -> APIResponse {
    APIResponse(statusCode: statusCode, data: data, headers: [:])
}

@Suite(.tags(.provider, .request))
struct APIProviderTests {
    @Test("shortCircuitHitResultSkipsClientAndNotifiesReceive")
    func shortCircuitHitResultSkipsClientAndNotifiesReceive() async throws {
        let log = EventLog()
        let response = makeResponse()
        let client = MockClient { _ in
            throw TestError.sample
        }
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let provider = APIProvider(
            client: client,
            builder: builder,
            plugins: [
                ShortCircuitProbe(decision: .hitResult(response)),
                ObserverProbe(log: log)
            ]
        )

        let result = try await provider.request(SimpleRequest())
        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 0)
        #expect(await log.all() == ["willSend", "didReceive"])
    }

    @Test("shortCircuitHitErrorMapsToAPIErrorAndNotifiesFail")
    func shortCircuitHitErrorMapsToAPIErrorAndNotifiesFail() async {
        let log = EventLog()
        let client = MockClient { _ in
            throw TestError.sample
        }
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let provider = APIProvider(
            client: client,
            builder: builder,
            plugins: [
                ShortCircuitProbe(decision: .hitError(TestError.sample)),
                ObserverProbe(log: log)
            ]
        )

        do {
            _ = try await provider.request(SimpleRequest())
            #expect(Bool(false))
        } catch let error as APIError {
            if case .underlying = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }

        #expect(client.requestCount == 0)
        #expect(await log.all() == ["willSend", "didFail"])
    }

    @Test("retriesOnceThenSucceeds")
    func retriesOnceThenSucceeds() async throws {
        let log = EventLog()
        let response = makeResponse()
        let counter = AttemptCounter()
        let client = MockClient { _ in
            let attempt = await counter.next()
            if attempt == 0 {
                throw TestError.sample
            }
            return response
        }
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let provider = APIProvider(
            client: client,
            builder: builder,
            plugins: [
                RetryProbe(log: log, decision: .retry),
                ObserverProbe(log: log)
            ]
        )

        let result = try await provider.request(SimpleRequest())
        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 2)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "didReceive"])
    }

    @Test("requestMapsUnderlyingErrors")
    func requestMapsUnderlyingErrors() async {
        let log = EventLog()
        let client = MockClient { _ in
            throw TestError.sample
        }
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let provider = APIProvider(
            client: client,
            builder: builder,
            plugins: [ObserverProbe(log: log)]
        )

        do {
            _ = try await provider.request(SimpleRequest())
            #expect(Bool(false))
        } catch let error as APIError {
            if case .underlying = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }

        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend", "didFail"])
    }

    @Test("decodeErrorsAreMappedToAPIError")
    func decodeErrorsAreMappedToAPIError() async {
        let client = MockClient { _ in
            makeResponse(data: Data("{}".utf8))
        }
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let provider = APIProvider(client: client, builder: builder)

        do {
            let _: EmptyResponse = try await provider.request(SimpleRequest(), decoder: ThrowingDecoder())
            #expect(Bool(false))
        } catch let error as APIError {
            if case .responseDecodingFailed = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }
}

private struct EmptyResponse: Decodable {}

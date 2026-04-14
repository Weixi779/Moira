import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request, .shortCircuit))
struct APIProviderShortCircuitTests {
    @Test("hitResultSkipsClientAndNotifiesReceive")
    func shortCircuitHitResultSkipsClientAndNotifiesReceive() async throws {
        let log = Support.EventLog()
        let response = Support.makeResponse()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ShortCircuitProbe(decision: .hitResult(response)),
                Support.ObserverProbe(log: log),
            ]
        )

        let result = try await provider.requestResponse(Support.SimpleRequest())

        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 0)
        #expect(await log.all() == ["willSend", "didReceive"])
    }

    @Test("hitResultProcessesResponseTransformBeforeReceive")
    func shortCircuitHitResultProcessesResponseTransformBeforeReceive() async throws {
        let log = Support.EventLog()
        let response = Support.makeResponse(statusCode: 201)
        let transform = Support.CountingTransformPlugin()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                transform,
                Support.ShortCircuitProbe(decision: .hitResult(response)),
                Support.ObserverProbe(log: log),
            ]
        )

        let result = try await provider.requestResponse(Support.SimpleRequest())
        let counts = await transform.counts()

        #expect(result.statusCode == response.statusCode)
        #expect(counts.prepare == 1)
        #expect(counts.adapt == 1)
        #expect(counts.process == 1)
        #expect(client.requestCount == 0)
        #expect(await log.all() == ["willSend", "didReceive"])
    }

    @Test("hitErrorMapsToAPIErrorAndNotifiesFail")
    func shortCircuitHitErrorMapsToAPIErrorAndNotifiesFail() async {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ShortCircuitProbe(decision: .hitError(Support.TestError.sample)),
                Support.ObserverProbe(log: log),
            ]
        )

        let error = await #expect(throws: APIError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        guard let error else { return }
        guard case .underlying = error else {
            Issue.record("Expected APIError.underlying when short-circuit returns an error.")
            return
        }

        #expect(client.requestCount == 0)
        #expect(await log.all() == ["willSend", "didFail"])
    }
}

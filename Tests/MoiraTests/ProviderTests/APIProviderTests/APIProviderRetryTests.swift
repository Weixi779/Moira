import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request, .retry))
struct APIProviderRetryTests {
    @Test(
        "retriesOnceThenSucceeds",
        arguments: zip(
            ["retry", "retryAfter0"],
            [RetryDecision.retry, .retryAfter(0)]
        )
    )
    func retriesOnceThenSucceeds(_ label: String, _ decision: RetryDecision) async throws {
        let log = Support.EventLog()
        let response = Support.makeResponse()
        let counter = Support.AttemptCounter()
        let client = Support.MockClient { _ in
            let attempt = await counter.next()
            if attempt == 0 {
                throw Support.TestError.sample
            }
            return response
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)],
            retryPlugin: Support.RetryProbe(log: log, decision: decision, policy: .reuseRequest)
        )

        let result = try await provider.requestResponse(Support.SimpleRequest())

        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 2)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }

    @Test("rebuildPolicyRebuildsRequestOnRetry")
    func rebuildPolicyRebuildsRequestOnRetry() async throws {
        let log = Support.EventLog()
        let response = Support.makeResponse()
        let counter = Support.AttemptCounter()
        let client = Support.MockClient { _ in
            let attempt = await counter.next()
            if attempt == 0 {
                throw Support.TestError.sample
            }
            return response
        }
        let transform = Support.CountingTransformPlugin()
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                transform,
                Support.ObserverProbe(log: log)
            ],
            retryPlugin: Support.RetryProbe(log: log, decision: .retry, policy: .rebuildRequest)
        )

        let result = try await provider.requestResponse(Support.SimpleRequest())
        let counts = await transform.counts()

        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 2)
        #expect(counts.prepare == 2)
        #expect(counts.adapt == 2)
        #expect(counts.process == 1)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }

    @Test(
        "retryShortCircuitHitSkipsSecondClientRequest",
        arguments: zip(
            ["retry", "retryAfter0"],
            [RetryDecision.retry, .retryAfter(0)]
        )
    )
    func retryShortCircuitHitSkipsSecondClientRequest(_ label: String, _ decision: RetryDecision) async throws {
        let log = Support.EventLog()
        let response = Support.makeResponse(statusCode: 204)
        let counter = Support.AttemptCounter()
        let client = Support.MockClient { _ in
            let attempt = await counter.next()
            if attempt == 0 {
                throw Support.TestError.sample
            }
            return Support.makeResponse(statusCode: 500)
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.RetryAwareShortCircuitProbe(response: response),
                Support.ObserverProbe(log: log)
            ],
            retryPlugin: Support.RetryProbe(log: log, decision: decision, policy: .reuseRequest)
        )

        let result = try await provider.requestResponse(Support.SimpleRequest())

        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }
}

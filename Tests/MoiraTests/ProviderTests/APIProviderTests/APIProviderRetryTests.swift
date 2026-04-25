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
            [
                RetryDecision.retry(.reuseRequest),
                .retryAfter(0, .reuseRequest),
            ]
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
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: decision
            )
        )

        let result = try await provider.request(Support.SimpleRequest())

        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 2)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }

    @Test("rebuildDecisionRebuildsRequestOnRetry")
    func rebuildDecisionRebuildsRequestOnRetry() async throws {
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
                Support.ObserverProbe(log: log),
            ],
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .retry(.rebuildRequest)
            )
        )

        let result = try await provider.request(Support.SimpleRequest())
        let counts = await transform.counts()

        #expect(result.statusCode == response.statusCode)
        #expect(client.requestCount == 2)
        #expect(counts.prepare == 2)
        #expect(counts.adapt == 2)
        #expect(counts.process == 1)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }

    @Test("defaultStrategyDoesNotRetryFailures")
    func defaultStrategyDoesNotRetryFailures() async {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )

        await #expect(throws: APIError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend", "didFail"])
    }

    @Test("doNotRetryStrategyReceivesFailureBeforeDidFail")
    func doNotRetryStrategyReceivesFailureBeforeDidFail() async {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)],
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .doNotRetry
            )
        )

        await #expect(throws: APIError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend", "shouldRetry", "didFail"])
    }

    @Test("rebuildStrategyDoesNotRetryAdaptFailures")
    func rebuildStrategyDoesNotRetryAdaptFailures() async {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            Support.makeResponse()
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ThrowingAdaptProbe(),
                Support.ObserverProbe(log: log),
            ],
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .retry(.rebuildRequest)
            )
        )

        await #expect(throws: APIError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        #expect(client.requestCount == 0)
        #expect(await log.all().isEmpty)
    }
}

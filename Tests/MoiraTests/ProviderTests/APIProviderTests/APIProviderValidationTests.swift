import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request))
struct APIProviderValidationTests {
    @Test("validationSuccessTriggersDidReceive")
    func validationSuccessTriggersDidReceive() async throws {
        let log = Support.EventLog()
        let validation = Support.CountingResponseValidationPlugin()
        let client = Support.MockClient { _ in
            Support.makeResponse()
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                validation,
                Support.ObserverProbe(log: log),
            ]
        )

        _ = try await provider.request(Support.SimpleRequest())

        #expect(await validation.count() == 1)
        #expect(await log.all() == ["willSend", "didReceive"])
    }

    @Test("validationFailureTriggersRetryStrategy")
    func validationFailureTriggersRetryStrategy() async throws {
        let log = Support.EventLog()
        let validation = Support.ThrowingOnceResponseValidationPlugin()
        let client = Support.MockClient { _ in
            Support.makeResponse()
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                validation,
                Support.ObserverProbe(log: log),
            ],
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .retry(.reuseRequest)
            )
        )

        _ = try await provider.request(Support.SimpleRequest())

        #expect(client.requestCount == 2)
        #expect(await validation.count() == 2)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }

    @Test("validationFailurePropagatesCustomError")
    func validationFailurePropagatesCustomError() async {
        let client = Support.MockClient { _ in
            Support.makeResponse()
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ThrowingResponseValidationProbe()]
        )

        await #expect(throws: Support.TestError.self) {
            try await provider.request(Support.SimpleRequest())
        }
    }
}

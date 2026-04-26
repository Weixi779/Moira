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
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])
    }

    @Test("reuseDecisionDoesNotRebuildRequestOnRetry")
    func reuseDecisionDoesNotRebuildRequestOnRetry() async throws {
        let response = Support.makeResponse()
        let counter = Support.AttemptCounter()
        let client = Support.MockClient { _ in
            let attempt = await counter.next()
            if attempt == 0 {
                throw Support.TestError.sample
            }
            return response
        }
        let builder = Support.CountingBuilder()
        let transform = Support.CountingTransformPlugin()
        let provider = APIProvider(
            client: client,
            builder: builder,
            plugins: [transform],
            retryStrategy: Support.RetryProbe(
                log: Support.EventLog(),
                decision: .retry(.reuseRequest)
            )
        )

        _ = try await provider.request(Support.SimpleRequest())
        let counts = await transform.counts()

        #expect(client.requestCount == 2)
        #expect(builder.buildCount == 1)
        #expect(counts.prepare == 1)
        #expect(counts.adapt == 1)
    }

    @Test("retrySnapshotsDescribeFailureAndNextAttempt")
    func retrySnapshotsDescribeFailureAndNextAttempt() async throws {
        let log = Support.EventLog()
        let capture = Support.SnapshotCapture()
        let response = Support.makeResponse()
        let validation = Support.ThrowingOnceResponseValidationPlugin()
        let client = Support.MockClient { _ in response }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                validation,
                Support.SnapshotObserverProbe(log: log, capture: capture),
            ],
            retryStrategy: Support.SnapshotRetryProbe(
                log: log,
                capture: capture,
                decision: .retry(.reuseRequest)
            )
        )

        _ = try await provider.request(Support.SimpleRequest())

        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "willSend", "didReceive"])

        let willSendSnapshots = await capture.all("willSend")
        let shouldRetrySnapshot = try #require(await capture.all("shouldRetry").first)
        let willRetrySnapshot = try #require(await capture.all("willRetry").first)

        try #require(willSendSnapshots.count == 2)
        let firstWillSend = try #require(willSendSnapshots.first)
        let secondWillSend = try #require(willSendSnapshots.last)

        #expect(firstWillSend.retryCount == 0)
        #expect(firstWillSend.error == nil)
        #expect(firstWillSend.response == nil)
        #expect(firstWillSend.request != nil)

        #expect(shouldRetrySnapshot.retryCount == 0)
        #expect((shouldRetrySnapshot.error as? Support.TestError) == .sample)
        #expect(shouldRetrySnapshot.response?.statusCode == response.statusCode)
        #expect(shouldRetrySnapshot.attemptStartedAt == firstWillSend.attemptStartedAt)

        #expect(willRetrySnapshot.retryCount == 0)
        #expect((willRetrySnapshot.error as? Support.TestError) == .sample)
        #expect(willRetrySnapshot.response?.statusCode == response.statusCode)
        #expect(willRetrySnapshot.attemptStartedAt == firstWillSend.attemptStartedAt)

        #expect(secondWillSend.retryCount == 1)
        #expect(secondWillSend.error == nil)
        #expect(secondWillSend.response == nil)
        #expect(secondWillSend.request != nil)
        #expect(secondWillSend.attemptStartedAt >= firstWillSend.attemptStartedAt)
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

        await #expect(throws: Support.TestError.self) {
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

        await #expect(throws: Support.TestError.self) {
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

        await #expect(throws: Support.TestError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        #expect(client.requestCount == 0)
        #expect(await log.all().isEmpty)
    }

    @Test("rebuildFailureAfterWillRetryFinalizesFailure")
    func rebuildFailureAfterWillRetryFinalizesFailure() async throws {
        let log = Support.EventLog()
        let capture = Support.SnapshotCapture()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ThrowingSecondAdaptProbe(error: .unimplemented),
                Support.SnapshotObserverProbe(log: log, capture: capture),
            ],
            retryStrategy: Support.SnapshotRetryProbe(
                log: log,
                capture: capture,
                decision: .retry(.rebuildRequest)
            )
        )

        let error = try #require(await #expect(throws: Support.TestError.self) {
            try await provider.request(Support.SimpleRequest())
        })

        #expect(error == .unimplemented)
        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend", "shouldRetry", "willRetry", "didFail"])

        let firstWillSend = try #require(await capture.all("willSend").first)
        let didFailSnapshot = try #require(await capture.all("didFail").first)
        #expect(await capture.all("willSend").count == 1)

        #expect(didFailSnapshot.retryCount == 1)
        #expect((didFailSnapshot.error as? Support.TestError) == .unimplemented)
        #expect(didFailSnapshot.response == nil)
        #expect(didFailSnapshot.request == nil)
        #expect(didFailSnapshot.attemptStartedAt == firstWillSend.attemptStartedAt)
    }

    @Test("cancellationDoesNotEnterRetryOrFailureHandling")
    func cancellationDoesNotEnterRetryOrFailureHandling() async {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            throw CancellationError()
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)],
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .retry(.reuseRequest)
            )
        )

        await #expect(throws: CancellationError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend"])
    }
}

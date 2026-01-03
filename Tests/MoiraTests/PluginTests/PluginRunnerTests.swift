import Foundation
import Testing
@testable import Moira

private struct TestRequest: APIRequest {
    let path: String = "/test"
    let method: RequestMethod = .get
    let payload: RequestPayload = .init()
}

private actor EventLog {
    private var events: [String] = []

    func add(_ event: String) {
        events.append(event)
    }

    func all() -> [String] {
        events
    }

    func clear() {
        events.removeAll()
    }
}

private struct TransformProbe: TransformPlugin {
    let name: String
    let log: EventLog

    func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
        await log.add("prepare:\(name)")
        return request
    }

    func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
        await log.add("adapt:\(name)")
        return request
    }

    func processResponse(_ response: APIResponse) async throws -> APIResponse {
        await log.add("process:\(name)")
        return response
    }
}

private struct ObserverProbe: ObserverPlugin {
    let name: String
    let log: EventLog

    func willSend(snapshot: RequestContext.Snapshot) async {
        await log.add("willSend:\(name)")
    }

    func didReceive(snapshot: RequestContext.Snapshot) async {
        await log.add("didReceive:\(name)")
    }

    func didFail(snapshot: RequestContext.Snapshot) async {
        await log.add("didFail:\(name)")
    }
}

private struct RetryProbe: RetryPlugin {
    let name: String
    let log: EventLog
    let decision: RetryDecision

    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        await log.add("shouldRetry:\(name)")
        return decision
    }

    func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async {
        await log.add("willRetry:\(name)")
    }
}

private struct ShortCircuitProbe: ShortCircuitPlugin {
    let name: String
    let log: EventLog
    let decision: ShortCircuitDecision

    func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision {
        await log.add("evaluate:\(name)")
        return decision
    }
}

private func makeSnapshot() async -> RequestContext.Snapshot {
    let context = RequestContext(target: TestRequest())
    return await context.snapshot()
}

private func makeResponse() -> APIResponse {
    APIResponse(statusCode: 200, data: Data(), headers: [:])
}

private struct TestError: Error {}

@Suite(.tags(.plugin, .runner))
struct PluginRunnerTransformTests {
    @Test("transformsInOrder")
    func pluginRunnerTransformsInOrder() async throws {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            TransformProbe(name: "one", log: log),
            TransformProbe(name: "two", log: log)
        ])

        let request = TestRequest()
        _ = try await runner.prepareRequest(request)
        _ = try await runner.adaptRequest(URLRequest(url: URL(string: "https://example.com")!))
        _ = try await runner.processResponse(makeResponse())

        let events = await log.all()
        #expect(events == [
            "prepare:one", "prepare:two",
            "adapt:one", "adapt:two",
            "process:one", "process:two"
        ])
    }

}

@Suite(.tags(.plugin, .runner))
struct PluginRunnerObserverTests {
    @Test("notifiesAllObservers")
    func pluginRunnerNotifiesAllObservers() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ObserverProbe(name: "one", log: log),
            ObserverProbe(name: "two", log: log)
        ])

        let snapshot = await makeSnapshot()

        await runner.willSend(snapshot: snapshot)
        #expect(Set(await log.all()) == Set(["willSend:one", "willSend:two"]))

        await log.clear()
        await runner.didReceive(snapshot: snapshot)
        #expect(Set(await log.all()) == Set(["didReceive:one", "didReceive:two"]))

        await log.clear()
        await runner.didFail(snapshot: snapshot)
        #expect(Set(await log.all()) == Set(["didFail:one", "didFail:two"]))
    }

}

@Suite(.tags(.plugin, .retry))
struct PluginRunnerRetryTests {
    @Test("stopsAtFirstNonDefaultDecision")
    func pluginRunnerRetryStopsAtFirstNonDefaultDecision() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            RetryProbe(name: "one", log: log, decision: .doNotRetry),
            RetryProbe(name: "two", log: log, decision: .retry)
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.shouldRetry(snapshot: snapshot, error: TestError())
        if case .retry = decision {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
        #expect(await log.all() == ["shouldRetry:one", "shouldRetry:two"])
    }

    @Test("skipsRemainingPluginsOnEarlyDecision")
    func pluginRunnerRetrySkipsRemainingPluginsOnEarlyDecision() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            RetryProbe(name: "one", log: log, decision: .retryAfter(1)),
            RetryProbe(name: "two", log: log, decision: .retry)
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.shouldRetry(snapshot: snapshot, error: TestError())
        if case .retryAfter(let delay) = decision {
            #expect(delay == 1)
        } else {
            #expect(Bool(false))
        }
        #expect(await log.all() == ["shouldRetry:one"])
    }

    @Test("willRetryNotifiesAllPluginsInOrder")
    func pluginRunnerWillRetryNotifiesAllPluginsInOrder() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            RetryProbe(name: "one", log: log, decision: .doNotRetry),
            RetryProbe(name: "two", log: log, decision: .doNotRetry)
        ])

        let snapshot = await makeSnapshot()
        await runner.willRetry(snapshot: snapshot, error: TestError(), decision: .retry)
        #expect(await log.all() == ["willRetry:one", "willRetry:two"])
    }

}

@Suite(.tags(.plugin, .shortCircuit))
struct PluginRunnerShortCircuitTests {
    @Test("stopsOnFirstHit")
    func pluginRunnerShortCircuitStopsOnFirstHit() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ShortCircuitProbe(name: "one", log: log, decision: .miss),
            ShortCircuitProbe(name: "two", log: log, decision: .hitResult(makeResponse())),
            ShortCircuitProbe(name: "three", log: log, decision: .hitResult(makeResponse()))
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.evaluate(snapshot: snapshot)
        if case .hitResult = decision {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
        #expect(await log.all() == ["evaluate:one", "evaluate:two"])
    }

    @Test("stopsOnFirstError")
    func pluginRunnerShortCircuitStopsOnFirstError() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ShortCircuitProbe(name: "one", log: log, decision: .miss),
            ShortCircuitProbe(name: "two", log: log, decision: .hitError(TestError())),
            ShortCircuitProbe(name: "three", log: log, decision: .hitResult(makeResponse()))
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.evaluate(snapshot: snapshot)
        if case .hitError = decision {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
        #expect(await log.all() == ["evaluate:one", "evaluate:two"])
    }
}

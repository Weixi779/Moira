import Foundation
import Testing
@testable import Moira

private struct TestRequest: APIRequest {
    let path: String = "/test"
    let method: RequestMethod = .get
    let payload: RequestPayload = .init()
    let execution: RequestExecution = .request
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

private let pluginRunnerBaseURL = URL(string: "https://unit-test.invalid")!

@Suite(.tags(.plugin, .runner))
struct PluginRunnerTransformTests {
    @Test("transformsInOrder")
    func pluginRunnerTransformsInOrder() async throws {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            TransformProbe(name: "one", log: log),
            TransformProbe(name: "two", log: log),
        ])

        let request = TestRequest()
        _ = try await runner.prepareRequest(request)
        _ = try await runner.adaptRequest(URLRequest(url: pluginRunnerBaseURL))
        _ = try await runner.processResponse(makeResponse())

        let events = await log.all()
        #expect(events == [
            "prepare:one", "prepare:two",
            "adapt:one", "adapt:two",
            "process:one", "process:two",
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
            ObserverProbe(name: "two", log: log),
        ])

        let snapshot = await makeSnapshot()

        await runner.willSend(snapshot: snapshot)
        #expect(await Set(log.all()) == Set(["willSend:one", "willSend:two"]))

        await log.clear()
        await runner.didReceive(snapshot: snapshot)
        #expect(await Set(log.all()) == Set(["didReceive:one", "didReceive:two"]))

        await log.clear()
        await runner.didFail(snapshot: snapshot)
        #expect(await Set(log.all()) == Set(["didFail:one", "didFail:two"]))
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
            ShortCircuitProbe(name: "three", log: log, decision: .hitResult(makeResponse())),
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.evaluate(snapshot: snapshot)
        guard case .hitResult = decision else {
            Issue.record("Expected the second short-circuit plugin to return a hit result.")
            return
        }

        #expect(await log.all() == ["evaluate:one", "evaluate:two"])
    }

    @Test("stopsOnFirstError")
    func pluginRunnerShortCircuitStopsOnFirstError() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ShortCircuitProbe(name: "one", log: log, decision: .miss),
            ShortCircuitProbe(name: "two", log: log, decision: .hitError(TestError())),
            ShortCircuitProbe(name: "three", log: log, decision: .hitResult(makeResponse())),
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.evaluate(snapshot: snapshot)
        guard case .hitError = decision else {
            Issue.record("Expected the second short-circuit plugin to return a hit error.")
            return
        }

        #expect(await log.all() == ["evaluate:one", "evaluate:two"])
    }

    @Test("allMissReturnsMiss")
    func pluginRunnerShortCircuitReturnsMissWhenAllPluginsMiss() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ShortCircuitProbe(name: "one", log: log, decision: .miss),
            ShortCircuitProbe(name: "two", log: log, decision: .miss),
        ])

        let snapshot = await makeSnapshot()
        let decision = await runner.evaluate(snapshot: snapshot)
        guard case .miss = decision else {
            Issue.record("Expected short-circuit evaluation to return .miss when all plugins miss.")
            return
        }

        #expect(await log.all() == ["evaluate:one", "evaluate:two"])
    }
}

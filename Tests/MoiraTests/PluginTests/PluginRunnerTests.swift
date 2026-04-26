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
}

private struct ResponseValidationProbe: ResponseValidationPlugin {
    let name: String
    let log: EventLog

    func validateResponse(_ response: APIResponse) async throws {
        await log.add("validate:\(name)")
    }
}

private struct ThrowingResponseValidationProbe: ResponseValidationPlugin {
    let name: String
    let log: EventLog

    func validateResponse(_ response: APIResponse) async throws {
        await log.add("validate:\(name)")
        throw TestError()
    }
}

private struct ObserverProbe: ObserverPlugin {
    let name: String
    let log: EventLog

    func willSend(snapshot: RequestSnapshot) async {
        await log.add("willSend:\(name)")
    }

    func didReceive(snapshot: RequestSnapshot) async {
        await log.add("didReceive:\(name)")
    }

    func didFail(snapshot: RequestSnapshot) async {
        await log.add("didFail:\(name)")
    }
}

private func makeSnapshot() async -> RequestSnapshot {
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

        let events = await log.all()
        #expect(events == [
            "prepare:one", "prepare:two",
            "adapt:one", "adapt:two",
        ])
    }
}

@Suite(.tags(.plugin, .runner))
struct PluginRunnerResponseValidationTests {
    @Test("validatesResponsesInOrder")
    func pluginRunnerValidatesResponsesInOrder() async throws {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ResponseValidationProbe(name: "one", log: log),
            ResponseValidationProbe(name: "two", log: log),
        ])

        try await runner.validateResponse(makeResponse())

        let events = await log.all()
        #expect(events == ["validate:one", "validate:two"])
    }

    @Test("stopsValidationAfterFirstError")
    func pluginRunnerStopsValidationAfterFirstError() async {
        let log = EventLog()
        let runner = PluginRunner(plugins: [
            ResponseValidationProbe(name: "one", log: log),
            ThrowingResponseValidationProbe(name: "two", log: log),
            ResponseValidationProbe(name: "three", log: log),
        ])

        await #expect(throws: TestError.self) {
            try await runner.validateResponse(makeResponse())
        }

        let events = await log.all()
        #expect(events == ["validate:one", "validate:two"])
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

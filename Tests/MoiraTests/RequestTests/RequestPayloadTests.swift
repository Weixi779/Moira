import Foundation
import Testing
@testable import Moira

private struct SampleBody: Codable, Equatable {
    let name: String
    let count: Int
}

@Suite(.tags(.request, .payload))
struct RequestPayloadTests {
    // MARK: - Defaults

    @Test("defaults")
    func defaults() {
        let payload = RequestPayload()
        #expect(payload.query.isEmpty)
        guard case .none = payload.body else {
            Issue.record("Expected payload body to default to .none.")
            return
        }
    }

    // MARK: - init(query:body:)

    @Test("init with query and body")
    func initWithQueryAndBody() throws {
        let body = SampleBody(name: "moira", count: 1)
        let payload = RequestPayload(
            query: [URLQueryItem(name: "page", value: "1")],
            body: .json(AnyJSONEncodable(body))
        )

        #expect(payload.query == [URLQueryItem(name: "page", value: "1")])
        guard case let .json(encodable) = payload.body else {
            Issue.record("Expected JSON body.")
            return
        }
        let data = try encodable.encode(using: JSONEncoder())
        let decoded = try JSONDecoder().decode(SampleBody.self, from: data)
        #expect(decoded == body)
    }

    // MARK: - Static Factories

    @Test("static query factory")
    func staticQuery() {
        let payload = RequestPayload.query("page", "1")
        #expect(payload.query == [URLQueryItem(name: "page", value: "1")])
        guard case .none = payload.body else {
            Issue.record("Expected body to be .none.")
            return
        }
    }

    @Test("static query factory with nil value")
    func staticQueryNilValue() {
        let payload = RequestPayload.query("flag", nil)
        #expect(payload.query == [URLQueryItem(name: "flag", value: nil)])
    }

    @Test("static queries factory")
    func staticQueries() {
        let items = [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2"),
        ]
        let payload = RequestPayload.queries(items)
        #expect(payload.query == items)
    }

    @Test("static queries factory with nil value")
    func staticQueriesNilValue() {
        let items = [URLQueryItem(name: "flag", value: nil)]
        let payload = RequestPayload.queries(items)
        #expect(payload.query == items)
    }

    @Test("static json factory")
    func staticJSON() throws {
        let body = SampleBody(name: "moira", count: 2)
        let payload = RequestPayload.json(body)

        #expect(payload.query.isEmpty)
        guard case let .json(encodable) = payload.body else {
            Issue.record("Expected JSON body.")
            return
        }
        let data = try encodable.encode(using: JSONEncoder())
        let decoded = try JSONDecoder().decode(SampleBody.self, from: data)
        #expect(decoded == body)
    }

    @Test("static formEncoded factory")
    func staticFormEncoded() {
        let items = [
            URLQueryItem(name: "email", value: "a@test.invalid"),
            URLQueryItem(name: "token", value: "123"),
        ]
        let payload = RequestPayload.formEncoded(items)

        #expect(payload.query.isEmpty)
        guard case let .urlEncodedForm(stored) = payload.body else {
            Issue.record("Expected URL-encoded form body.")
            return
        }
        #expect(stored == items)
    }

    @Test("static data factory")
    func staticData() {
        let raw = Data([0x01, 0x02, 0x03])
        let payload = RequestPayload.data(raw)

        #expect(payload.query.isEmpty)
        guard case let .data(stored) = payload.body else {
            Issue.record("Expected raw data body.")
            return
        }
        #expect(stored == raw)
    }

    // MARK: - Chaining: Query (append semantics)

    @Test("chaining multiple queries preserves order")
    func chainingQueryOrder() {
        let payload = RequestPayload.query("a", "1")
            .query("b", "2")
            .query("c", "3")

        #expect(payload.query == [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2"),
            URLQueryItem(name: "c", value: "3"),
        ])
    }

    @Test("chaining queries batch appends")
    func chainingQueriesBatch() {
        let payload = RequestPayload.query("a", "1")
            .queries([
                URLQueryItem(name: "b", value: "2"),
                URLQueryItem(name: "c", value: "3"),
            ])

        #expect(payload.query == [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2"),
            URLQueryItem(name: "c", value: "3"),
        ])
    }

    @Test("chaining query with nil value")
    func chainingQueryNilValue() {
        let payload = RequestPayload.query("page", "1")
            .query("verbose", nil)

        #expect(payload.query == [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "verbose", value: nil),
        ])
    }

    // MARK: - Chaining: Body (override semantics)

    @Test("chaining json body")
    func chainingJSON() throws {
        let body = SampleBody(name: "moira", count: 3)
        let payload = RequestPayload.query("page", "1")
            .json(body)

        #expect(payload.query == [URLQueryItem(name: "page", value: "1")])
        guard case let .json(encodable) = payload.body else {
            Issue.record("Expected JSON body.")
            return
        }
        let data = try encodable.encode(using: JSONEncoder())
        let decoded = try JSONDecoder().decode(SampleBody.self, from: data)
        #expect(decoded == body)
    }

    @Test("chaining formEncoded body")
    func chainingFormEncoded() {
        let items = [URLQueryItem(name: "k", value: "v")]
        let payload = RequestPayload.query("q", "1")
            .formEncoded(items)

        guard case let .urlEncodedForm(stored) = payload.body else {
            Issue.record("Expected URL-encoded form body.")
            return
        }
        #expect(stored == items)
    }

    @Test("chaining data body")
    func chainingData() {
        let raw = Data([0xFF])
        let payload = RequestPayload.query("q", "1")
            .data(raw)

        guard case let .data(stored) = payload.body else {
            Issue.record("Expected raw data body.")
            return
        }
        #expect(stored == raw)
    }

    @Test("body override: later call replaces earlier")
    func bodyOverride() {
        let raw = Data([0x01])
        let payload = RequestPayload.json(SampleBody(name: "a", count: 1))
            .data(raw)

        guard case let .data(stored) = payload.body else {
            Issue.record("Expected data body to override json.")
            return
        }
        #expect(stored == raw)
    }

    // MARK: - Value Semantics

    @Test("chaining does not mutate original")
    func valueSemantics() {
        let original = RequestPayload.query("a", "1")
        let derived = original.query("b", "2").json(SampleBody(name: "x", count: 0))

        #expect(original.query.count == 1)
        guard case .none = original.body else {
            Issue.record("Original body should remain .none.")
            return
        }
        #expect(derived.query.count == 2)
        guard case .json = derived.body else {
            Issue.record("Derived body should be .json.")
            return
        }
    }
}

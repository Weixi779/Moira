import Foundation
import Testing
@testable import Moira

private struct SampleBody: Codable, Equatable {
    let name: String
    let count: Int
}

@Suite(.tags(.request, .payload))
struct RequestPayloadTests {
    @Test("defaults")
    func requestPayloadDefaults() {
        let payload = RequestPayload()
        #expect(payload.query.isEmpty)
        guard case .none = payload.body else {
            Issue.record("Expected payload body to default to .none.")
            return
        }
    }

    @Test("appendingQueryItem")
    func requestPayloadAppendingQueryItem() {
        let item = URLQueryItem(name: "q", value: "1")
        let payload = RequestPayload().appendingQueryItem(item)

        #expect(payload.query == [item])
    }

    @Test("appendingQueryItems")
    func requestPayloadAppendingQueryItems() {
        let items = [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2"),
        ]
        let payload = RequestPayload().appendingQueryItems(items)

        #expect(payload.query == items)
    }

    @Test("replacingQueryItem")
    func requestPayloadReplacingQueryItem() {
        let original = RequestPayload(query: [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2"),
        ])
        let payload = original.replacingQueryItem(URLQueryItem(name: "a", value: "9"))

        #expect(payload.query == [
            URLQueryItem(name: "b", value: "2"),
            URLQueryItem(name: "a", value: "9"),
        ])
        #expect(original.query == [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2"),
        ])
    }

    @Test("replacingQueryItems")
    func requestPayloadReplacingQueryItems() {
        let original = RequestPayload(query: [URLQueryItem(name: "a", value: "1")])
        let items = [URLQueryItem(name: "c", value: "3")]
        let payload = original.replacingQueryItems(items)

        #expect(payload.query == items)
        #expect(original.query == [URLQueryItem(name: "a", value: "1")])
    }

    @Test("withJSONBody")
    func requestPayloadWithJSONBody() throws {
        let body = SampleBody(name: "moira", count: 2)
        let payload = RequestPayload().withJSON(body)

        guard case let .json(encodable) = payload.body else {
            Issue.record("Expected payload body to store JSON data.")
            return
        }

        let data = try encodable.encode(using: JSONEncoder())
        let decoded = try JSONDecoder().decode(SampleBody.self, from: data)
        #expect(decoded == body)
    }

    @Test("withURLEncodedForm")
    func requestPayloadWithURLEncodedForm() {
        let items = [
            URLQueryItem(name: "email", value: "a@unit-test.invalid"),
            URLQueryItem(name: "token", value: "123"),
        ]
        let payload = RequestPayload().withURLEncodedForm(items)

        guard case let .urlEncodedForm(encoded) = payload.body else {
            Issue.record("Expected payload body to store URL-encoded form items.")
            return
        }

        #expect(encoded == items)
    }

    @Test("withDataBody")
    func requestPayloadWithDataBody() {
        let data = Data([0x01, 0x02, 0x03])
        let payload = RequestPayload().withData(data)

        guard case let .data(stored) = payload.body else {
            Issue.record("Expected payload body to store raw data.")
            return
        }

        #expect(stored == data)
    }
}

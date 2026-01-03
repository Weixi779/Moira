import Foundation
import Testing
@testable import Moira

private struct SampleBody: Codable, Sendable, Equatable {
    let name: String
    let count: Int
}

@Suite(.tags(.request, .payload))
struct RequestPayloadTests {
    @Test("defaults")
    func requestPayloadDefaults() {
        let payload = RequestPayload()
        #expect(payload.query.isEmpty)
        if case .none = payload.body {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
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
            URLQueryItem(name: "b", value: "2")
        ]
        let payload = RequestPayload().appendingQueryItems(items)

        #expect(payload.query == items)
    }

    @Test("replacingQueryItem")
    func requestPayloadReplacingQueryItem() {
        let original = RequestPayload(query: [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2")
        ])
        let payload = original.replacingQueryItem(URLQueryItem(name: "a", value: "9"))

        #expect(payload.query == [
            URLQueryItem(name: "b", value: "2"),
            URLQueryItem(name: "a", value: "9")
        ])
        #expect(original.query == [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2")
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

        if case .json(let encodable) = payload.body {
            let data = try encodable.encode(using: JSONEncoder())
            let decoded = try JSONDecoder().decode(SampleBody.self, from: data)
            #expect(decoded == body)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("withURLEncodedForm")
    func requestPayloadWithURLEncodedForm() {
        let items = [
            URLQueryItem(name: "email", value: "a@example.com"),
            URLQueryItem(name: "token", value: "123")
        ]
        let payload = RequestPayload().withURLEncodedForm(items)

        if case .urlEncodedForm(let encoded) = payload.body {
            #expect(encoded == items)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("withDataBody")
    func requestPayloadWithDataBody() {
        let data = Data([0x01, 0x02, 0x03])
        let payload = RequestPayload().withData(data)

        if case .data(let stored) = payload.body {
            #expect(stored == data)
        } else {
            #expect(Bool(false))
        }
    }

    @Test("withUploadBody")
    func requestPayloadWithUploadBody() {
        let data = Data([0x05, 0x06])
        let payload = RequestPayload().withUpload(.data(data))

        if case .upload(let source) = payload.body {
            if case .data(let stored) = source {
                #expect(stored == data)
            } else {
                #expect(Bool(false))
            }
        } else {
            #expect(Bool(false))
        }
    }
}

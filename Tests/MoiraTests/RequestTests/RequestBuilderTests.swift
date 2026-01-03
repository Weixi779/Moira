import Foundation
import Testing
@testable import Moira

private struct SimpleRequest: APIRequest {
    let path: String
    let method: RequestMethod
    let payload: RequestPayload
    let baseURL: URL?
    let headers: [String: String]?
    let timeout: TimeInterval

    init(
        path: String = "/v1/resource",
        method: RequestMethod = .get,
        payload: RequestPayload = .init(),
        baseURL: URL? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) {
        self.path = path
        self.method = method
        self.payload = payload
        self.baseURL = baseURL
        self.headers = headers
        self.timeout = timeout
    }
}

@Suite(.tags(.request, .builder))
struct RequestBuilderTests {
    @Test("buildUsesBaseURLAndMethod")
    func buildUsesBaseURLAndMethod() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(path: "/v2/users", method: .post)

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://example.com/v2/users")
        #expect(built.httpMethod == "POST")
    }

    @Test("buildUsesTargetBaseURLOverride")
    func buildUsesTargetBaseURLOverride() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(
            path: "/v2/users",
            baseURL: URL(string: "https://override.example.com")
        )

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://override.example.com/v2/users")
    }

    @Test("buildAppliesQueryItems")
    func buildAppliesQueryItems() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let payload = RequestPayload(query: [
            URLQueryItem(name: "q", value: "moira"),
            URLQueryItem(name: "page", value: "1")
        ])
        let request = SimpleRequest(path: "/search", payload: payload)

        let built = try builder.build(request)
        let components = URLComponents(url: built.url!, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        #expect(Set(items) == Set(payload.query))
    }

    @Test("buildAppliesHeadersAndTimeout")
    func buildAppliesHeadersAndTimeout() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(
            headers: ["X-Token": "abc"],
            timeout: 15
        )

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "X-Token") == "abc")
        #expect(built.timeoutInterval == 15)
    }

    @Test("buildEncodesJSONBodyAndContentType")
    func buildEncodesJSONBodyAndContentType() throws {
        struct Body: Codable, Sendable, Equatable { let value: String }
        let body = Body(value: "ok")
        let payload = RequestPayload().withJSON(body)
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let decoded = try JSONDecoder().decode(Body.self, from: built.httpBody ?? Data())
        #expect(decoded == body)
    }

    @Test("buildKeepsExistingContentTypeHeader")
    func buildKeepsExistingContentTypeHeader() throws {
        struct Body: Codable, Sendable { let value: String }
        let payload = RequestPayload().withJSON(Body(value: "ok"))
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(
            method: .post,
            payload: payload,
            headers: ["Content-Type": "application/custom"]
        )

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/custom")
    }

    @Test("buildEncodesURLEncodedForm")
    func buildEncodesURLEncodedForm() throws {
        let items = [
            URLQueryItem(name: "a", value: "1"),
            URLQueryItem(name: "b", value: "2")
        ]
        let payload = RequestPayload().withURLEncodedForm(items)
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8")
        let body = String(data: built.httpBody ?? Data(), encoding: .utf8)
        #expect(body == "a=1&b=2")
    }

    @Test("buildEncodesDataBody")
    func buildEncodesDataBody() throws {
        let data = Data([0x01, 0x02])
        let payload = RequestPayload().withData(data)
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(built.httpBody == data)
    }

    @Test("buildSetsContentTypeForUploadDataOrFile")
    func buildSetsContentTypeForUploadDataOrFile() throws {
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)

        let dataPayload = RequestPayload().withUpload(.data(Data([0x01])))
        let dataRequest = SimpleRequest(method: .post, payload: dataPayload)
        let dataBuilt = try builder.build(dataRequest)
        #expect(dataBuilt.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")

        let filePayload = RequestPayload().withUpload(.file(URL(fileURLWithPath: "/tmp/file.txt")))
        let fileRequest = SimpleRequest(method: .post, payload: filePayload)
        let fileBuilt = try builder.build(fileRequest)
        #expect(fileBuilt.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test("buildSkipsContentTypeForMultipartUpload")
    func buildSkipsContentTypeForMultipartUpload() throws {
        let parts = [MultipartFormPart(name: "file", data: Data([0x01]))]
        let payload = RequestPayload().withUpload(.multipart(parts))
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test("buildThrowsOnInvalidPath")
    func buildThrowsOnInvalidPath() {
        let builder = RequestBuilder(baseURL: URL(string: "https://example.com")!)
        let request = SimpleRequest(path: "http://bad url")

        do {
            _ = try builder.build(request)
            #expect(Bool(false))
        } catch let error as APIError {
            if case .requestBuildingFailed = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }
}

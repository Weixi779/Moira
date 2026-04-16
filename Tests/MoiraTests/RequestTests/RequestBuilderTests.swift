import Foundation
import Testing
@testable import Moira

private let requestBuilderBaseURL = URL(string: "https://unit-test.invalid")!
private let requestBuilderOverrideBaseURL = URL(string: "https://override.unit-test.invalid")!

private struct SimpleRequest: APIRequest {
    let path: String
    let method: RequestMethod
    let payload: RequestPayload
    let execution: RequestExecution
    let baseURL: URL?
    let headers: [String: String]?
    let timeout: TimeInterval

    init(
        path: String = "/v1/resource",
        method: RequestMethod = .get,
        payload: RequestPayload = .init(),
        execution: RequestExecution = .request,
        baseURL: URL? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) {
        self.path = path
        self.method = method
        self.payload = payload
        self.execution = execution
        self.baseURL = baseURL
        self.headers = headers
        self.timeout = timeout
    }
}

@Suite(.tags(.request, .builder))
struct RequestBuilderTests {
    @Test("buildUsesBaseURLAndMethod")
    func buildUsesBaseURLAndMethod() throws {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(path: "/v2/users", method: .post)

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://unit-test.invalid/v2/users")
        #expect(built.httpMethod == "POST")
    }

    @Test("buildUsesTargetBaseURLOverride")
    func buildUsesTargetBaseURLOverride() throws {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(
            path: "/v2/users",
            baseURL: requestBuilderOverrideBaseURL
        )

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://override.unit-test.invalid/v2/users")
    }

    @Test("buildAppliesQueryItems")
    func buildAppliesQueryItems() throws {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let payload = RequestPayload(query: [
            URLQueryItem(name: "q", value: "moira"),
            URLQueryItem(name: "page", value: "1"),
        ])
        let request = SimpleRequest(path: "/search", payload: payload)

        let built = try builder.build(request)
        let url = try #require(built.url, "Expected the built request to contain a URL.")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        #expect(Set(items) == Set(payload.query))
    }

    @Test("buildAppliesHeadersAndTimeout")
    func buildAppliesHeadersAndTimeout() throws {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
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
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let bodyData = try #require(built.httpBody, "Expected the JSON request to contain a body.")
        let decoded = try JSONDecoder().decode(Body.self, from: bodyData)
        #expect(decoded == body)
    }

    @Test("buildKeepsExistingContentTypeHeader")
    func buildKeepsExistingContentTypeHeader() throws {
        struct Body: Codable, Sendable { let value: String }
        let payload = RequestPayload().withJSON(Body(value: "ok"))
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
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
            URLQueryItem(name: "b", value: "2"),
        ]
        let payload = RequestPayload().withURLEncodedForm(items)
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8")
        let bodyData = try #require(built.httpBody, "Expected the form request to contain a body.")
        let body = try #require(
            String(data: bodyData, encoding: .utf8),
            "Expected the form request body to be valid UTF-8."
        )
        #expect(body == "a=1&b=2")
    }

    @Test("buildEncodesDataBody")
    func buildEncodesDataBody() throws {
        let data = Data([0x01, 0x02])
        let payload = RequestPayload().withData(data)
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, payload: payload)

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        let bodyData = try #require(built.httpBody, "Expected the raw-data request to contain a body.")
        #expect(bodyData == data)
    }

    @Test(
        "buildSetsContentTypeForUploadDataOrFile",
        arguments: zip(
            ["data", "file"],
            [
                UploadSource.data(Data([0x01])),
                UploadSource.file(URL(fileURLWithPath: "/tmp/file.txt")),
            ]
        )
    )
    func buildSetsContentTypeForUploadDataOrFile(_ label: String, _ source: UploadSource) throws {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, execution: .upload(source))

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test("buildSkipsContentTypeForMultipartUpload")
    func buildSkipsContentTypeForMultipartUpload() throws {
        let parts = [MultipartFormPart(name: "file", data: Data([0x01]))]
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, execution: .upload(.multipart(parts)))

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test("buildThrowsInvalidRequestForUploadWithNonEmptyBody")
    func buildThrowsInvalidRequestForUploadWithNonEmptyBody() {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(
            method: .post,
            payload: RequestPayload().withData(Data([0x01])),
            execution: .upload(.data(Data([0x02])))
        )

        let error = #expect(throws: APIError.self) {
            try builder.build(request)
        }

        guard let error else { return }
        guard case .invalidRequest = error else {
            Issue.record("Expected APIError.invalidRequest for upload with non-empty body.")
            return
        }
    }

    @Test("buildThrowsOnInvalidPath")
    func buildThrowsOnInvalidPath() {
        let builder = RequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(path: "http://bad url")

        let error = #expect(throws: APIError.self) {
            try builder.build(request)
        }

        guard let error else { return }
        guard case .requestBuildingFailed = error else {
            Issue.record("Expected APIError.requestBuildingFailed for an invalid path.")
            return
        }
    }
}

import Foundation
import Testing
@testable import Moira

private let requestBuilderBaseURL = URL(string: "https://unit-test.invalid")!
private let requestBuilderOverrideBaseURL = URL(string: "https://override.unit-test.invalid")!
private let requestBuilderVersionedBaseURL = URL(string: "https://unit-test.invalid/v1")!
private let requestBuilderVersionedTrailingSlashBaseURL = URL(string: "https://unit-test.invalid/v1/")!

// MARK: - Fixtures

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

struct PathResolutionCase {
    let baseURL: URL
    let path: String
    let expectedURL: String
}

// MARK: - Tests

@Suite(.tags(.request, .builder))
struct URLRequestBuilderTests {
    @Test("buildUsesBaseURLAndMethod")
    func buildUsesBaseURLAndMethod() throws {
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(path: "/v2/users", method: .post)

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://unit-test.invalid/v2/users")
        #expect(built.httpMethod == "POST")
    }

    @Test("buildUsesTargetBaseURLOverride")
    func buildUsesTargetBaseURLOverride() throws {
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(
            path: "/v2/users",
            baseURL: requestBuilderOverrideBaseURL
        )

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://override.unit-test.invalid/v2/users")
    }

    @Test(
        "buildAppendsEndpointPath",
        arguments: [
            PathResolutionCase(
                baseURL: requestBuilderVersionedBaseURL,
                path: "users",
                expectedURL: "https://unit-test.invalid/v1/users"
            ),
            PathResolutionCase(
                baseURL: requestBuilderVersionedBaseURL,
                path: "/users",
                expectedURL: "https://unit-test.invalid/v1/users"
            ),
            PathResolutionCase(
                baseURL: requestBuilderVersionedTrailingSlashBaseURL,
                path: "users",
                expectedURL: "https://unit-test.invalid/v1/users"
            ),
            PathResolutionCase(
                baseURL: requestBuilderVersionedTrailingSlashBaseURL,
                path: "/users",
                expectedURL: "https://unit-test.invalid/v1/users"
            ),
            PathResolutionCase(
                baseURL: URL(string: "https://unit-test.invalid/api/mobile/")!,
                path: "/login",
                expectedURL: "https://unit-test.invalid/api/mobile/login"
            ),
            PathResolutionCase(
                baseURL: requestBuilderVersionedBaseURL,
                path: "users/123/profile",
                expectedURL: "https://unit-test.invalid/v1/users/123/profile"
            ),
        ]
    )
    func buildAppendsEndpointPath(_ testCase: PathResolutionCase) throws {
        let builder = URLRequestBuilder(baseURL: testCase.baseURL)
        let request = SimpleRequest(path: testCase.path)

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == testCase.expectedURL)
    }

    @Test("buildAppliesQueryItems")
    func buildAppliesQueryItems() throws {
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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

    @Test("buildUsesBaseURLWhenPathIsEmpty")
    func buildUsesBaseURLWhenPathIsEmpty() throws {
        let builder = URLRequestBuilder(baseURL: requestBuilderVersionedBaseURL)
        let request = SimpleRequest(path: "")

        let built = try builder.build(request)
        #expect(built.url?.absoluteString == "https://unit-test.invalid/v1")
    }

    @Test("buildAppendsPayloadQueryAfterBaseURLQuery")
    func buildAppendsPayloadQueryAfterBaseURLQuery() throws {
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
        let targetBaseURL = try #require(
            URL(string: "https://override.unit-test.invalid/v2?lang=en&region=cn"),
            "Expected the test base URL to be valid."
        )
        let payload = RequestPayload(query: [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "filter", value: "active"),
        ])
        let request = SimpleRequest(
            path: "",
            payload: payload,
            baseURL: targetBaseURL
        )

        let built = try builder.build(request)
        #expect(
            built.url?.absoluteString ==
                "https://override.unit-test.invalid/v2?lang=en&region=cn&page=1&filter=active"
        )

        let url = try #require(built.url, "Expected the built request to contain a URL.")
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false),
            "Expected the built request URL to be decomposable."
        )
        #expect(components.queryItems == [
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "region", value: "cn"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "filter", value: "active"),
        ])
    }

    @Test("buildAppliesHeadersAndTimeout")
    func buildAppliesHeadersAndTimeout() throws {
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, execution: .upload(source))

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test("buildSkipsContentTypeForMultipartUpload")
    func buildSkipsContentTypeForMultipartUpload() throws {
        let parts = [MultipartFormPart(name: "file", data: Data([0x01]))]
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
        let request = SimpleRequest(method: .post, execution: .upload(.multipart(parts)))

        let built = try builder.build(request)
        #expect(built.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test("buildThrowsInvalidRequestForUploadWithNonEmptyBody")
    func buildThrowsInvalidRequestForUploadWithNonEmptyBody() {
        let builder = URLRequestBuilder(baseURL: requestBuilderBaseURL)
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
}

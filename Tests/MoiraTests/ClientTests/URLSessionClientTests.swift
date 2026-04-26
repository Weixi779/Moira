import Foundation
import Testing
@testable import Moira

private struct URLSessionClientStubResponse {
    let statusCode: Int
    let headers: [String: String]
    let data: Data

    init(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        data: Data = Data()
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

private final class URLSessionClientCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?
    private var body: Data?

    func record(request: URLRequest) {
        lock.lock()
        self.request = request
        self.body = Self.captureBody(from: request)
        lock.unlock()
    }

    func snapshot() -> (request: URLRequest?, body: Data?) {
        lock.lock()
        defer { lock.unlock() }
        return (request, body)
    }

    private static func captureBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data
    }
}

private final class URLSessionClientStubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> URLSessionClientStubResponse

    private static let lock = NSLock()
    private static var handlers: [URL: Handler] = [:]

    static func register(url: URL, handler: @escaping Handler) {
        lock.lock()
        handlers[url] = handler
        lock.unlock()
    }

    static func unregister(url: URL) {
        lock.lock()
        handlers[url] = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return handler(for: url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let handler = Self.handler(for: url)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let stub = try handler(request)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
            )
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func handler(for url: URL) -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[url]
    }
}

enum URLSessionUploadBodyScenario: String, CaseIterable, CustomTestStringConvertible {
    case data
    case file

    var testDescription: String {
        rawValue
    }

    var method: String {
        switch self {
        case .data:
            return "POST"
        case .file:
            return "PUT"
        }
    }

    func makeUploadSource() throws -> URLSessionUploadSourceFixture {
        switch self {
        case .data:
            let data = Data("raw-upload".utf8)
            return URLSessionUploadSourceFixture(source: .data(data), body: data)
        case .file:
            let data = Data("file-upload".utf8)
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("moira-urlsession-client-\(UUID().uuidString)")
            try data.write(to: fileURL)
            return URLSessionUploadSourceFixture(source: .file(fileURL), body: data) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

struct URLSessionUploadSourceFixture {
    let source: UploadSource
    let body: Data
    let cleanup: @Sendable () -> Void

    init(
        source: UploadSource,
        body: Data,
        cleanup: @escaping @Sendable () -> Void = {}
    ) {
        self.source = source
        self.body = body
        self.cleanup = cleanup
    }
}

@Suite(.tags(.client))
struct URLSessionClientTests {
    @Test("requestReturnsAPIResponse")
    func requestReturnsAPIResponse() async throws {
        let client = Self.makeClient()
        let data = Data("{\"ok\":true}".utf8)

        let response = try await Self.withStub { _ in
            URLSessionClientStubResponse(
                statusCode: 201,
                headers: ["X-Test": "request"],
                data: data
            )
        } operation: { url in
            try await client.request(URLRequest(url: url))
        }

        #expect(response.statusCode == 201)
        #expect(response.data == data)
        #expect(response.headers["X-Test"] == "request")
    }

    @Test("uploadSendsExpectedBody", arguments: URLSessionUploadBodyScenario.allCases)
    func uploadSendsExpectedBody(_ scenario: URLSessionUploadBodyScenario) async throws {
        let fixture = try scenario.makeUploadSource()
        defer { fixture.cleanup() }

        let result = try await Self.captureUpload(
            source: fixture.source,
            method: scenario.method
        )

        #expect(result.body == fixture.body)
        #expect(result.request.httpMethod == scenario.method)
        #expect(result.response.statusCode == 200)
        #expect(result.response.data == Data("ok".utf8))
    }

    @Test("multipartUploadSetsContentTypeAndEncodesParts")
    func multipartUploadSetsContentTypeAndEncodesParts() async throws {
        let client = Self.makeClient()
        let capture = URLSessionClientCapture()
        let parts = [
            MultipartFormPart(name: "metadata", data: Data("{\"a\":1}".utf8), mimeType: "application/json"),
            MultipartFormPart(name: "blob", data: Data([0x01]), fileName: "blob.bin"),
            MultipartFormPart(name: "file", data: Data([0x02]), fileName: "photo.jpg", mimeType: "image/jpeg"),
        ]

        let response = try await Self.withStub { request in
            capture.record(request: request)
            return URLSessionClientStubResponse(data: Data("ok".utf8))
        } operation: { url in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            let task = try client.upload(request, source: .multipart(parts))
            return try await task.response()
        }

        let snapshot = capture.snapshot()
        let contentType = try #require(snapshot.request?.value(forHTTPHeaderField: "Content-Type"))
        let body = try #require(snapshot.body)

        #expect(contentType.contains("multipart/form-data"))
        #expect(contentType.contains("boundary=moira.boundary."))
        #expect(!contentType.contains("application/octet-stream"))
        #expect(body.range(of: Data("Content-Disposition: form-data; name=\"metadata\"".utf8)) != nil)
        #expect(body.range(of: Data("Content-Type: application/json".utf8)) != nil)
        #expect(body.range(of: Data("filename=\"blob.bin\"".utf8)) != nil)
        #expect(body.range(of: Data("Content-Type: application/octet-stream".utf8)) != nil)
        #expect(body.range(of: Data("filename=\"photo.jpg\"".utf8)) != nil)
        #expect(body.range(of: Data("Content-Type: image/jpeg".utf8)) != nil)
        #expect(response.statusCode == 200)
    }

    @Test("requestWrapsURLSessionErrors")
    func requestWrapsURLSessionErrors() async throws {
        let client = Self.makeClient()

        let error = await #expect(throws: APIError.self) {
            try await Self.withStub { _ in
                throw URLError(.notConnectedToInternet)
            } operation: { url in
                try await client.request(URLRequest(url: url))
            }
        }

        guard case let .underlying(error, response) = error else {
            Issue.record("Expected APIError.underlying from URLSessionClient.")
            return
        }
        #expect((error as? URLError)?.code == .notConnectedToInternet)
        #expect(response == nil)
    }

    private static func makeClient() -> URLSessionClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLSessionClientStubURLProtocol.self]
        return URLSessionClient(configuration: configuration)
    }

    private static func makeURL() -> URL {
        URL(string: "https://urlsession-client.test/\(UUID().uuidString)")!
    }

    private static func withStub<T>(
        handler: @escaping URLSessionClientStubURLProtocol.Handler,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let url = makeURL()
        URLSessionClientStubURLProtocol.register(url: url, handler: handler)
        defer { URLSessionClientStubURLProtocol.unregister(url: url) }
        return try await operation(url)
    }

    private static func captureUpload(
        source: UploadSource,
        method: String
    ) async throws -> (response: APIResponse, request: URLRequest, body: Data) {
        let client = makeClient()
        let capture = URLSessionClientCapture()

        let response = try await withStub { request in
            capture.record(request: request)
            return URLSessionClientStubResponse(data: Data("ok".utf8))
        } operation: { url in
            var request = URLRequest(url: url)
            request.httpMethod = method
            let task = try client.upload(request, source: source)
            return try await task.response()
        }

        let snapshot = capture.snapshot()
        let request = try #require(snapshot.request)
        let body = try #require(snapshot.body)
        return (response, request, body)
    }
}

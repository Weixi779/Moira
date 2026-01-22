import Alamofire
import Foundation
import Testing
@testable import Moira

final class CaptureURLProtocol: URLProtocol {
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
              ) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data([0x00]))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite
struct AlamofireClientTests {
    @Test("multipartUploadClearsContentType")
    func multipartUploadClearsContentType() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CaptureURLProtocol.self]
        let session = Session(configuration: configuration)
        let client = AlamofireClient(session: session)

        var request = URLRequest(url: URL(string: "https://example.com/upload")!)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let parts = [MultipartFormPart(name: "file", data: Data([0x01]))]

        CaptureURLProtocol.lastRequest = nil
        let task = try client.upload(request, source: .multipart(parts))
        let response = try await task.response()

        guard let capturedRequest = CaptureURLProtocol.lastRequest else {
            #expect(Bool(false))
            return
        }

        let contentType = capturedRequest.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.contains("multipart/form-data"))
        #expect(!contentType.contains("application/octet-stream"))

        #expect(response.statusCode == 200)
    }
}

import Alamofire
import Foundation
import Testing
@testable import Moira

private let alamofireClientUploadURL = URL(string: "https://unit-test.invalid/upload")!

final class CaptureURLProtocol: URLProtocol {
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = captureBody(from: request)

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: nil
              )
        else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data([0x00]))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func captureBody(from request: URLRequest) -> Data? {
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

@Suite(.tags(.client))
struct AlamofireClientTests {
    @Test("multipartUploadClearsContentType")
    func multipartUploadClearsContentType() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CaptureURLProtocol.self]
        let session = Session(configuration: configuration)
        let client = AlamofireClient(session: session)

        var request = URLRequest(url: alamofireClientUploadURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let parts = [
            MultipartFormPart(name: "metadata", data: Data("{\"a\":1}".utf8), fileName: nil, mimeType: "application/json"),
            MultipartFormPart(name: "blob", data: Data([0x01]), fileName: "blob.bin", mimeType: nil),
            MultipartFormPart(name: "file", data: Data([0x02]), fileName: "photo.jpg", mimeType: "image/jpeg"),
        ]

        CaptureURLProtocol.lastRequest = nil
        CaptureURLProtocol.lastBody = nil
        let task = try client.upload(request, source: .multipart(parts))
        let response = try await task.response()

        let capturedRequest = try #require(
            CaptureURLProtocol.lastRequest,
            "Expected the upload request to be captured by the custom URL protocol."
        )

        let contentType = capturedRequest.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.contains("multipart/form-data"))
        #expect(!contentType.contains("application/octet-stream"))

        let body = try #require(
            CaptureURLProtocol.lastBody,
            "Expected the multipart upload body to be captured by the custom URL protocol."
        )

        #expect(body.range(of: Data("Content-Type: application/json".utf8)) != nil)
        #expect(body.range(of: Data("Content-Type: application/octet-stream".utf8)) != nil)
        #expect(body.range(of: Data("Content-Type: image/jpeg".utf8)) != nil)
        #expect(body.range(of: Data("filename=\"blob.bin\"".utf8)) != nil)
        #expect(body.range(of: Data("filename=\"photo.jpg\"".utf8)) != nil)

        #expect(response.statusCode == 200)
    }
}

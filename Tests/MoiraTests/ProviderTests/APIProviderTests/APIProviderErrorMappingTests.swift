import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request))
struct APIProviderErrorMappingTests {
    @Test("requestPropagatesCustomClientErrors")
    func requestPropagatesCustomClientErrors() async {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )

        await #expect(throws: Support.TestError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        #expect(client.requestCount == 1)
        #expect(await log.all() == ["willSend", "didFail"])
    }

    @Test("didFailSnapshotIncludesResponseFromUnderlyingError")
    func didFailSnapshotIncludesResponseFromUnderlyingError() async {
        let capture = Support.ResponseCapture()
        let body = Data("bad request".utf8)
        let response = Support.makeResponse(statusCode: 400, data: body)
        let client = Support.MockClient { _ in
            throw APIError.underlying(Support.TestError.sample, response: response)
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ResponseCaptureProbe(capture: capture)]
        )

        await #expect(throws: APIError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        let snapshotResponse = await capture.get()
        #expect(snapshotResponse?.statusCode == 400)
        #expect(snapshotResponse?.data == body)
    }

    @Test("didFailSnapshotIncludesResponseWhenValidationThrows")
    func didFailSnapshotIncludesResponseWhenValidationThrows() async {
        let capture = Support.ResponseCapture()
        let body = Data("boom".utf8)
        let response = Support.makeResponse(statusCode: 500, data: body)
        let client = Support.MockClient { _ in
            response
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ThrowingResponseValidationProbe(),
                Support.ResponseCaptureProbe(capture: capture),
            ]
        )

        await #expect(throws: Support.TestError.self) {
            try await provider.request(Support.SimpleRequest())
        }

        let snapshotResponse = await capture.get()
        #expect(snapshotResponse?.statusCode == 500)
        #expect(snapshotResponse?.data == body)
    }
}

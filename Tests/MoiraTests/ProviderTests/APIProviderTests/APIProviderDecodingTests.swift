import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request))
struct APIProviderDecodingTests {
    @Test("requestTaskDecodedUsesProviderDecoder")
    func requestTaskDecodedUsesProviderDecoder() async throws {
        let client = Support.MockClient { _ in
            Support.makeResponse(data: Data("{}".utf8))
        }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())

        let task: RequestTask<Support.EmptyResponse> = try await provider.requestTask(Support.SimpleRequest())
        _ = try await task.response()

        #expect(client.requestCount == 1)
    }

    @Test("requestTaskDecodedMapsDecodingErrors")
    func requestTaskDecodedMapsDecodingErrors() async {
        let client = Support.MockClient { _ in
            Support.makeResponse(data: Data("{}".utf8))
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            decoder: Support.ThrowingDecoder()
        )

        let error = await #expect(throws: APIError.self) {
            let task: RequestTask<Support.EmptyResponse> = try await provider.requestTask(Support.SimpleRequest())
            _ = try await task.response()
        }

        guard let error else { return }
        guard case .responseDecodingFailed = error else {
            Issue.record("Expected APIError.responseDecodingFailed from requestTask decoding.")
            return
        }
    }

    @Test("decodeErrorsAreMappedToAPIError")
    func decodeErrorsAreMappedToAPIError() async {
        let client = Support.MockClient { _ in
            Support.makeResponse(data: Data("{}".utf8))
        }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())

        let error = await #expect(throws: APIError.self) {
            let _: Support.EmptyResponse = try await provider.request(
                Support.SimpleRequest(),
                decoder: Support.ThrowingDecoder()
            )
        }

        guard let error else { return }
        guard case .responseDecodingFailed = error else {
            Issue.record("Expected APIError.responseDecodingFailed from request decoding.")
            return
        }
    }
}

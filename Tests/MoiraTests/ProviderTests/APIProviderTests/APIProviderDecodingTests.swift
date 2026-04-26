import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request))
struct APIProviderDecodingTests {
    @Test("requestDecodedUsesProviderDecoder")
    func requestDecodedUsesProviderDecoder() async throws {
        let client = Support.MockClient { _ in
            Support.makeResponse(data: Data("{}".utf8))
        }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())

        let _: Support.EmptyResponse = try await provider.request(Support.SimpleRequest())

        #expect(client.requestCount == 1)
    }

    @Test("requestDecodedMapsDecodingErrors")
    func requestDecodedMapsDecodingErrors() async throws {
        let client = Support.MockClient { _ in
            Support.makeResponse(data: Data("{}".utf8))
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            decoder: Support.ThrowingDecoder()
        )

        let error = try #require(await #expect(throws: APIError.self) {
            let _: Support.EmptyResponse = try await provider.request(Support.SimpleRequest())
        })

        guard case .responseDecodingFailed = error else {
            Issue.record("Expected APIError.responseDecodingFailed from request decoding.")
            return
        }
    }

    @Test("decodeErrorsAreMappedToAPIError")
    func decodeErrorsAreMappedToAPIError() async throws {
        let client = Support.MockClient { _ in
            Support.makeResponse(data: Data("{}".utf8))
        }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())

        let error = try #require(await #expect(throws: APIError.self) {
            let _: Support.EmptyResponse = try await provider.request(
                Support.SimpleRequest(),
                decoder: Support.ThrowingDecoder()
            )
        })

        guard case .responseDecodingFailed = error else {
            Issue.record("Expected APIError.responseDecodingFailed from request decoding.")
            return
        }
    }
}

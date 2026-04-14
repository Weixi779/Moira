import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request))
struct APIProviderLifecycleTests {
    @Test("providerDeallocationCancelsRequest")
    func providerDeallocationCancelsRequest() async throws {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            Support.makeResponse()
        }
        var provider: APIProvider? = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )

        let task = try await provider!.requestTask(Support.SimpleRequest())
        provider = nil

        await #expect(throws: CancellationError.self) {
            _ = try await task.response()
        }

        #expect(client.requestCount == 0)
        #expect(await log.all() == ["willSend"])
    }
}

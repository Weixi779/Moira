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
            // Suspend long enough for provider to be deallocated.
            try await Task.sleep(for: .seconds(10))
            return Support.makeResponse()
        }
        var provider: APIProvider? = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )

        let task = Task { [provider] in
            try await provider?.request(Support.SimpleRequest())
        }
        // Give the task time to start.
        try await Task.sleep(for: .milliseconds(50))
        provider = nil
        task.cancel()

        await #expect(throws: (any Error).self) {
            _ = try await task.value
        }
    }
}

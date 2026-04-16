import Foundation
import Testing
@testable import Moira

private typealias Support = APIProviderTestSupport

@Suite(.tags(.provider, .request))
struct APIProviderUploadTests {
    @Test("uploadTaskReturnsUploadTask")
    func uploadTaskReturnsUploadTask() async throws {
        let response = Support.makeResponse(data: Data("ok".utf8))
        let client = Support.MockClient { _ in response }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        let task = try await provider.uploadTask(request)
        let result = try await task.response()

        #expect(result.statusCode == 200)
        #expect(client.uploadCount == 1)
        #expect(client.requestCount == 0)
    }

    @Test("uploadTaskDecodedReturnsDecodedResponse")
    func uploadTaskDecodedReturnsDecodedResponse() async throws {
        let json = Data("{\"value\":42}".utf8)
        let client = Support.MockClient { _ in Support.makeResponse(data: json) }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        let task: UploadTask<DecodableValue> = try await provider.uploadTask(request)
        let result = try await task.response()

        #expect(result.value == 42)
    }

    @Test("uploadDoesNotTriggerRetry")
    func uploadDoesNotTriggerRetry() async throws {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            throw Support.TestError.sample
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)],
            retryPlugin: Support.RetryProbe(log: log, decision: .retry, policy: .reuseRequest)
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        await #expect(throws: (any Error).self) {
            let task = try await provider.uploadTask(request)
            _ = try await task.response()
        }

        #expect(client.uploadCount == 1)
        let events = await log.all()
        #expect(!events.contains("shouldRetry"))
    }

    @Test("snapshotExecutionKindIsUploadForUploadRequest")
    func snapshotExecutionKindIsUploadForUploadRequest() async throws {
        let capture = Support.ExecutionKindCapture()
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ExecutionKindProbe(capture: capture)]
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        let task = try await provider.uploadTask(request)
        _ = try await task.response()

        let kind = await capture.get()
        #expect(kind == .upload)
    }

    @Test("snapshotExecutionKindIsRequestForRegularRequest")
    func snapshotExecutionKindIsRequestForRegularRequest() async throws {
        let capture = Support.ExecutionKindCapture()
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ExecutionKindProbe(capture: capture)]
        )

        try await provider.request(Support.SimpleRequest())

        let kind = await capture.get()
        #expect(kind == .request)
    }

    @Test("uploadTaskThrowsForNonUploadExecution")
    func uploadTaskThrowsForNonUploadExecution() async {
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())

        let error = await #expect(throws: APIError.self) {
            _ = try await provider.uploadTask(Support.SimpleRequest())
        }

        guard let error else { return }
        guard case .invalidRequest = error else {
            Issue.record("Expected APIError.invalidRequest for non-upload execution.")
            return
        }
    }

    @Test("uploadWithNonEmptyBodyThrowsInvalidRequest")
    func uploadWithNonEmptyBodyThrowsInvalidRequest() async {
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(client: client, builder: Support.makeBuilder())
        let request = Support.SimpleRequest(
            method: .post,
            payload: .data(Data([0x01])),
            execution: .upload(.data(Data([0x02])))
        )

        let error = await #expect(throws: APIError.self) {
            _ = try await provider.uploadTask(request)
        }

        guard let error else { return }
        guard case .invalidRequest = error else {
            Issue.record("Expected APIError.invalidRequest for upload with non-empty body.")
            return
        }
    }
}

private struct DecodableValue: Decodable {
    let value: Int
}

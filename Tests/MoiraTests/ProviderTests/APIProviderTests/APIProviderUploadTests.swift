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

    @Test("uploadTaskDecodeFailureDoesNotTriggerDidFail")
    func uploadTaskDecodeFailureDoesNotTriggerDidFail() async throws {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in Support.makeResponse(data: Data("invalid".utf8)) }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        let task: UploadTask<DecodableValue> = try await provider.uploadTask(request)
        let error = try #require(await #expect(throws: APIError.self) {
            _ = try await task.response()
        })

        guard case .responseDecodingFailed = error else {
            Issue.record("Expected APIError.responseDecodingFailed for upload typed decode failure.")
            return
        }
        #expect(await log.all() == ["willSend", "didReceive"])
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
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .retry(.rebuildRequest)
            )
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        let error = try #require(await #expect(throws: Support.TestError.self) {
            let task = try await provider.uploadTask(request)
            _ = try await task.response()
        })

        #expect(error == .sample)
        #expect(client.uploadCount == 1)
        let events = await log.all()
        #expect(!events.contains("shouldRetry"))
    }

    @Test("uploadValidationFailureDoesNotTriggerRetry")
    func uploadValidationFailureDoesNotTriggerRetry() async throws {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in
            Support.makeResponse()
        }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ThrowingResponseValidationProbe(log: log),
                Support.ObserverProbe(log: log),
            ],
            retryStrategy: Support.RetryProbe(
                log: log,
                decision: .retry(.rebuildRequest)
            )
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        await #expect(throws: Support.TestError.self) {
            let task = try await provider.uploadTask(request)
            _ = try await task.response()
        }

        #expect(client.uploadCount == 1)
        let events = await log.all()
        #expect(events == ["willSend", "validate", "didFail"])
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

    @Test("regularRequestUsesPreparedExecutionKind")
    func regularRequestUsesPreparedExecutionKind() async throws {
        let capture = Support.ExecutionKindCapture()
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ExecutionTransformPlugin(execution: .request),
                Support.ExecutionKindProbe(capture: capture),
            ]
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        _ = try await provider.request(request)

        #expect(client.requestCount == 1)
        #expect(client.uploadCount == 0)
        #expect(await capture.get() == .request)
    }

    @Test("uploadTaskUsesPreparedUploadSource")
    func uploadTaskUsesPreparedUploadSource() async throws {
        let preparedData = Data([0x02, 0x03])
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [
                Support.ExecutionTransformPlugin(execution: .upload(.data(preparedData))),
            ]
        )

        let task = try await provider.uploadTask(Support.SimpleRequest(method: .post))
        _ = try await task.response()

        let uploadedSource = try #require(client.uploadedSource)
        guard case let .data(uploadedData) = uploadedSource else {
            Issue.record("Expected upload client to receive prepared data source.")
            return
        }
        #expect(uploadedData == preparedData)
    }

    @Test("uploadTaskThrowsForNonUploadExecution")
    func uploadTaskThrowsForNonUploadExecution() async throws {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )

        let error = try #require(await #expect(throws: APIError.self) {
            _ = try await provider.uploadTask(Support.SimpleRequest())
        })

        guard case .invalidRequest = error else {
            Issue.record("Expected APIError.invalidRequest for non-upload execution.")
            return
        }
        #expect(await log.all().isEmpty)
    }

    @Test("uploadTaskThrowsCapabilityNotSupportedForRequestOnlyClient")
    func uploadTaskThrowsCapabilityNotSupportedForRequestOnlyClient() async throws {
        let log = Support.EventLog()
        let client = Support.RequestOnlyClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )
        let request = Support.SimpleRequest(
            method: .post,
            execution: .upload(.data(Data([0x01])))
        )

        let error = try #require(await #expect(throws: APIError.self) {
            _ = try await provider.uploadTask(request)
        })

        guard case .capabilityNotSupported = error else {
            Issue.record("Expected APIError.capabilityNotSupported for request-only client uploads.")
            return
        }
        #expect(await log.all().isEmpty)
    }

    @Test("uploadWithNonEmptyBodyThrowsInvalidRequest")
    func uploadWithNonEmptyBodyThrowsInvalidRequest() async throws {
        let log = Support.EventLog()
        let client = Support.MockClient { _ in Support.makeResponse() }
        let provider = APIProvider(
            client: client,
            builder: Support.makeBuilder(),
            plugins: [Support.ObserverProbe(log: log)]
        )
        let request = Support.SimpleRequest(
            method: .post,
            payload: .data(Data([0x01])),
            execution: .upload(.data(Data([0x02])))
        )

        let error = try #require(await #expect(throws: APIError.self) {
            _ = try await provider.uploadTask(request)
        })

        guard case .invalidRequest = error else {
            Issue.record("Expected APIError.invalidRequest for upload with non-empty body.")
            return
        }
        #expect(await log.all().isEmpty)
    }
}

private struct DecodableValue: Decodable {
    let value: Int
}

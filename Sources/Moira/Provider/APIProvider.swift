import Foundation

/// Default provider implementation that runs the request pipeline.
public final class APIProvider: APIProviding, @unchecked Sendable {
    private let client: any APIClient
    private let uploadClient: (any APIUploadClient)?
    private let builder: any URLRequestBuilding
    private let runner: PluginRunner
    private let decoder: ResponseDecoder
    private let retryStrategy: any RetryStrategy

    /// Creates a provider with a client, builder, and optional plugins.
    public init(
        client: any APIClient,
        builder: any URLRequestBuilding,
        decoder: ResponseDecoder = JSONDecoder(),
        plugins: [any RequestPlugin] = [],
        retryStrategy: any RetryStrategy = NoRetryStrategy()
    ) {
        self.client = client
        self.uploadClient = client as? any APIUploadClient
        self.builder = builder
        self.runner = PluginRunner(plugins: plugins)
        self.decoder = decoder
        self.retryStrategy = retryStrategy
    }

    /// Executes a request and returns the raw response.
    @discardableResult
    public func request(_ target: any APIRequest) async throws -> APIResponse {
        try await executeRequest(target)
    }

    /// Executes a request and decodes the response using the default decoder.
    public func request<T: Decodable>(_ target: any APIRequest) async throws -> T {
        try await request(target, decoder: decoder)
    }

    /// Executes a request and decodes the response using the provided decoder.
    public func request<T: Decodable>(
        _ target: any APIRequest,
        decoder: ResponseDecoder
    ) async throws -> T {
        let response = try await request(target)
        do {
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw APIError.responseDecodingFailed(error)
        }
    }

    /// Returns an upload task with progress for the raw response.
    public func uploadTask(_ target: any APIRequest) async throws -> UploadTask<APIResponse> {
        let context = RequestContext(target: target)
        try await prepare(context: context)

        let prepared = try await context.currentPreparedTarget()
        guard case let .upload(source) = prepared.execution else {
            throw APIError.invalidRequest("uploadTask requires execution == .upload.")
        }

        let uploadClient = try requireUploadClient()
        let request = try await context.currentURLRequest()
        await beginSendingAttempt(context: context)
        return try await executeUpload(
            source: source,
            request: request,
            context: context,
            uploadClient: uploadClient
        )
    }

    /// Returns an upload task with progress that decodes the response body.
    public func uploadTask<T: Decodable & Sendable>(_ target: any APIRequest) async throws -> UploadTask<T> {
        let task: UploadTask<APIResponse> = try await uploadTask(target)
        let responseClosure = { @Sendable [weak self] () async throws -> T in
            guard let self else {
                throw CancellationError()
            }
            let response = try await task.response()
            do {
                return try self.decoder.decode(T.self, from: response.data)
            } catch {
                throw APIError.responseDecodingFailed(error)
            }
        }
        return UploadTask<T>(progress: task.progress, response: responseClosure)
    }
}

private extension APIProvider {
    // MARK: - Regular Requests

    /// Executes a regular request through the retry strategy.
    func executeRequest(_ target: any APIRequest) async throws -> APIResponse {
        let context = RequestContext(target: target)
        try await prepare(context: context)
        try await ensureRegularRequest(context: context)

        while !Task.isCancelled {
            do {
                await beginSendingAttempt(context: context)
                return try await sendRequest(context: context)
            } catch {
                if error is CancellationError {
                    throw error
                }

                await recordFailure(error, context: context)
                let snapshot = await context.snapshot()
                let decision = await retryStrategy.shouldRetry(snapshot: snapshot, error: error)

                switch decision {
                case .doNotRetry:
                    await notifyDidFail(context: context)
                    throw error
                case let .retry(behavior):
                    try await prepareNextRetry(
                        decision: decision,
                        snapshot: snapshot,
                        error: error,
                        behavior: behavior,
                        context: context
                    )
                case let .retryAfter(delay, behavior):
                    try await prepareNextRetry(
                        decision: decision,
                        delay: delay,
                        snapshot: snapshot,
                        error: error,
                        behavior: behavior,
                        context: context
                    )
                }
            }
        }
        throw CancellationError()
    }

    /// Performs the actual transport and successful response validation for a built request.
    func sendRequest(context: RequestContext) async throws -> APIResponse {
        let request = try await context.currentURLRequest()
        let response = try await client.request(request)
        try await validateResponse(response, context: context)
        await notifyDidReceive(context: context)
        return response
    }

    func ensureRegularRequest(context: RequestContext) async throws {
        let prepared = try await context.currentPreparedTarget()
        guard case .request = prepared.execution else {
            throw APIError.invalidRequest("request requires execution == .request.")
        }
    }

    // MARK: - Retry

    /// Runs retry side effects before the next regular request attempt starts.
    func prepareNextRetry(
        decision: RetryDecision,
        delay: TimeInterval? = nil,
        snapshot: RequestSnapshot,
        error: Error,
        behavior: RetryRequestBehavior,
        context: RequestContext
    ) async throws {
        await retryStrategy.willRetry(snapshot: snapshot, error: error, decision: decision)
        await context.beginRetryPreparation(rebuildsRequest: behavior == .rebuildRequest)
        if let delay {
            try await Task.sleep(for: .seconds(delay))
        }

        guard behavior == .rebuildRequest else { return }

        do {
            try await prepare(context: context)
            try await ensureRegularRequest(context: context)
        } catch {
            await recordFailure(error, context: context)
            await notifyDidFail(context: context)
            throw error
        }
    }

    // MARK: - Uploads

    /// Executes an upload without retry, returning an UploadTask.
    func executeUpload(
        source: UploadSource,
        request: URLRequest,
        context: RequestContext,
        uploadClient: any APIUploadClient
    ) async throws -> UploadTask<APIResponse> {
        let task: UploadTask<APIResponse>
        do {
            task = try uploadClient.upload(request, source: source)
        } catch {
            await recordFailure(error, context: context)
            await notifyDidFail(context: context)
            throw error
        }

        let responseClosure = { @Sendable [weak self] () async throws -> APIResponse in
            guard let self else {
                throw CancellationError()
            }
            do {
                let response = try await task.response()
                try await self.validateResponse(response, context: context)
                await self.notifyDidReceive(context: context)
                return response
            } catch {
                await self.recordFailure(error, context: context)
                await self.notifyDidFail(context: context)
                throw error
            }
        }
        return UploadTask(progress: task.progress, response: responseClosure)
    }

    func requireUploadClient() throws -> any APIUploadClient {
        guard let uploadClient else {
            throw APIError.capabilityNotSupported("Current client does not support uploads.")
        }
        return uploadClient
    }

    // MARK: - Preparation and Validation

    /// Builds and adapts the request without notifying observers.
    func prepare(context: RequestContext) async throws {
        let target = await context.originalTarget()
        let (prepared, adapted) = try await buildRequest(for: target)
        await context.setPreparedTargetAndRequest(prepared, request: adapted)
    }

    func buildRequest(for target: any APIRequest) async throws -> (any APIRequest, URLRequest) {
        let prepared = try await runner.prepareRequest(target)
        let built = try builder.build(prepared)
        let adapted = try await runner.adaptRequest(built)
        return (prepared, adapted)
    }

    /// Stores and validates the raw response.
    func validateResponse(_ response: APIResponse, context: RequestContext) async throws {
        await context.recordResponse(response)
        try await runner.validateResponse(response)
    }

    /// Stores failure details for observer and retry snapshots.
    func recordFailure(_ error: Error, context: RequestContext) async {
        await context.recordFailure(error)
    }

    // MARK: - Observer Notifications

    /// Starts a transport attempt and notifies observers.
    func beginSendingAttempt(context: RequestContext) async {
        await context.beginSendingAttempt()
        await notifyWillSend(context: context)
    }

    /// Notifies observers before sending a request.
    func notifyWillSend(context: RequestContext) async {
        let snapshot = await context.snapshot()
        await runner.willSend(snapshot: snapshot)
    }

    /// Notifies observers about a successful response.
    func notifyDidReceive(context: RequestContext) async {
        let snapshot = await context.snapshot()
        await runner.didReceive(snapshot: snapshot)
    }

    /// Notifies observers about a failure.
    func notifyDidFail(context: RequestContext) async {
        let snapshot = await context.snapshot()
        await runner.didFail(snapshot: snapshot)
    }
}

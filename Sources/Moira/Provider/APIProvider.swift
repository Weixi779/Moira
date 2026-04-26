import Foundation

/// Default provider implementation that runs the request pipeline.
public final class APIProvider: APIProviding, @unchecked Sendable {
    private let client: APIClient
    private let builder: any URLRequestBuilding
    private let runner: PluginRunner
    private let decoder: ResponseDecoder
    private let retryStrategy: any RetryStrategy

    /// Creates a provider with a client, builder, and optional plugins.
    public init(
        client: APIClient,
        builder: any URLRequestBuilding,
        decoder: ResponseDecoder = JSONDecoder(),
        plugins: [any RequestPlugin] = [],
        retryStrategy: any RetryStrategy = NoRetryStrategy()
    ) {
        self.client = client
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
        let pipeline = try await preparePipeline(for: target)

        guard case let .upload(source) = pipeline.prepared.execution else {
            throw APIError.invalidRequest("uploadTask requires execution == .upload.")
        }
        return try await executeUpload(source: source, request: pipeline.request, context: pipeline.context)
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
    struct Pipeline {
        let target: any APIRequest
        let prepared: any APIRequest
        let request: URLRequest
        let context: RequestContext
    }

    /// Executes a regular request through the retry strategy.
    func executeRequest(_ target: any APIRequest) async throws -> APIResponse {
        var pipeline = try await preparePipeline(for: target)

        while !Task.isCancelled {
            do {
                return try await sendRequest(pipeline.request, context: pipeline.context)
            } catch {
                if error is CancellationError {
                    throw error
                }

                await recordFailure(error, context: pipeline.context)
                let snapshot = await pipeline.context.snapshot()
                let decision = await retryStrategy.shouldRetry(snapshot: snapshot, error: error)

                switch decision {
                case .doNotRetry:
                    await notifyDidFail(context: pipeline.context)
                    throw error
                case let .retry(behavior):
                    try await prepareNextRetry(
                        decision: decision,
                        snapshot: snapshot,
                        error: error,
                        context: pipeline.context
                    )
                    pipeline = try await nextPipeline(
                        behavior: behavior,
                        target: target,
                        current: pipeline
                    )
                case let .retryAfter(delay, behavior):
                    try await prepareNextRetry(
                        decision: decision,
                        delay: delay,
                        snapshot: snapshot,
                        error: error,
                        context: pipeline.context
                    )
                    pipeline = try await nextPipeline(
                        behavior: behavior,
                        target: target,
                        current: pipeline
                    )
                }
            }
        }
        throw CancellationError()
    }

    /// Builds and adapts the request, then notifies observers.
    func preparePipeline(
        for target: any APIRequest,
        context existingContext: RequestContext? = nil,
        resetForRetry: Bool = false
    ) async throws -> Pipeline {
        let (prepared, adapted) = try await buildRequest(for: target)

        let context = existingContext ?? RequestContext(target: target)
        if resetForRetry {
            await context.resetForRetry(request: adapted)
        } else {
            await context.updateRequest(adapted)
        }

        await notifyWillSend(context: context)

        return Pipeline(
            target: target,
            prepared: prepared,
            request: adapted,
            context: context
        )
    }

    /// Prepares the URLRequest for the next retry attempt.
    func nextPipeline(
        behavior: RetryRequestBehavior,
        target: any APIRequest,
        current: Pipeline
    ) async throws -> Pipeline {
        switch behavior {
        case .reuseRequest:
            await current.context.resetForRetry(request: current.request)
            await notifyWillSend(context: current.context)
            return current
        case .rebuildRequest:
            return try await preparePipeline(
                for: target,
                context: current.context,
                resetForRetry: true
            )
        }
    }

    /// Performs the actual transport and successful response validation for a built request.
    func sendRequest(_ request: URLRequest, context: RequestContext) async throws -> APIResponse {
        let response = try await client.request(request)
        try await validateResponse(response, context: context)
        await notifyDidReceive(context: context)
        return response
    }

    /// Stores and validates the raw response.
    func validateResponse(_ response: APIResponse, context: RequestContext) async throws {
        await context.updateResponse(response)
        try await runner.validateResponse(response)
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

    /// Stores failure details for observer and retry snapshots.
    func recordFailure(_ error: Error, context: RequestContext) async {
        await context.updateError(error)
        if let response = Self.response(from: error) {
            await context.updateResponse(response)
        }
    }

    /// Runs retry side effects before the next attempt starts.
    func prepareNextRetry(
        decision: RetryDecision,
        delay: TimeInterval? = nil,
        snapshot: RequestContext.Snapshot,
        error: Error,
        context: RequestContext
    ) async throws {
        await retryStrategy.willRetry(snapshot: snapshot, error: error, decision: decision)
        await context.incrementRetryCount()
        if let delay {
            try await Task.sleep(for: .seconds(delay))
        }
    }

    /// Executes an upload without retry, returning an UploadTask.
    func executeUpload(
        source: UploadSource,
        request: URLRequest,
        context: RequestContext
    ) async throws -> UploadTask<APIResponse> {
        let task = try client.upload(request, source: source)
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
                await context.updateError(error)
                if let response = Self.response(from: error) {
                    await context.updateResponse(response)
                }
                await self.notifyDidFail(context: context)
                throw error
            }
        }
        return UploadTask(progress: task.progress, response: responseClosure)
    }

    func buildRequest(for target: any APIRequest) async throws -> (any APIRequest, URLRequest) {
        let prepared = try await runner.prepareRequest(target)
        let built = try builder.build(prepared)
        let adapted = try await runner.adaptRequest(built)
        return (prepared, adapted)
    }

    static func response(from error: Error) -> APIResponse? {
        guard case let APIError.underlying(_, response) = error else {
            return nil
        }
        return response
    }
}

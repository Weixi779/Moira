import Foundation

/// Default provider implementation that runs the request pipeline.
public final class APIProvider: APIProviding, @unchecked Sendable {
    private let client: APIClient
    private let builder: RequestBuilder
    private let runner: PluginRunner
    private let decoder: ResponseDecoder

    /// Creates a provider with a client, builder, and optional plugins.
    public init(
        client: APIClient,
        builder: RequestBuilder,
        decoder: ResponseDecoder = JSONDecoder(),
        plugins: [any RequestPlugin] = []
    ) {
        self.client = client
        self.builder = builder
        self.runner = PluginRunner(plugins: plugins)
        self.decoder = decoder
    }
    
    /// Executes a request and returns the raw response.
    @discardableResult
    public func requestResponse(_ target: any APIRequest) async throws -> APIResponse {
        let task = try await requestTask(target)
        return try await task.response()
    }
    
    /// Executes a request while discarding the response body.
    public func request(_ target: any APIRequest) async throws {
        try await requestResponse(target)
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
        let response = try await requestResponse(target)
        do {
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw APIError.responseDecodingFailed(error)
        }
    }

    /// Builds a pipeline, evaluates short-circuit plugins, and returns a task.
    public func requestTask(_ target: any APIRequest) async throws -> RequestTask {
        do {
            let pipeline = try await preparePipeline(for: target)

            if let task = await tryShortCircuit(pipeline) {
                return wrapTask(task)
            }

            let task = try await execute(pipeline)
            return wrapTask(task)
        } catch {
            throw mapToAPIError(error)
        }
    }
}

private extension APIProvider {
    struct Pipeline {
        let prepared: any APIRequest
        let request: URLRequest
        let context: RequestContext
        let snapshot: RequestContext.Snapshot

        var executionKind: ExecutionKind {
            if case .upload(let source) = prepared.payload.body {
                return .upload(source: source, request: request)
            }
            return .request(request)
        }
    }

    /// Builds and adapts the request, then notifies observers.
    func preparePipeline(for target: any APIRequest) async throws -> Pipeline {
        let prepared = try await runner.prepareRequest(target)
        let built = try builder.build(prepared)
        let adapted = try await runner.adaptRequest(built)

        let context = RequestContext(target: prepared)
        await context.updateRequest(adapted)

        let snapshot = await context.snapshot()
        await runner.willSend(snapshot: snapshot)

        return Pipeline(
            prepared: prepared,
            request: adapted,
            context: context,
            snapshot: snapshot
        )
    }

    /// Returns a task if a short-circuit plugin provides a result.
    func tryShortCircuit(_ pipeline: Pipeline) async -> RequestTask? {
        let decision = await runner.evaluate(snapshot: pipeline.snapshot)
        switch decision {
        case .hitResult(let response, _):
            let responseClosure = { @Sendable () async throws -> APIResponse in
                let processed = try await self.processResponse(response, context: pipeline.context)
                await self.notifyDidReceive(context: pipeline.context)
                return processed
            }
            return RequestTask(progress: nil, response: responseClosure)
        case .hitError(let error, _):
            let responseClosure = { @Sendable () async throws -> APIResponse in
                await pipeline.context.updateError(error)
                await self.notifyDidFail(context: pipeline.context)
                throw error
            }
            return RequestTask(progress: nil, response: responseClosure)
        case .miss:
            return nil
        }
    }

    /// Creates a request task based on the execution kind.
    func execute(_ pipeline: Pipeline) async throws -> RequestTask {
        switch pipeline.executionKind {
        case .upload(let source, let request):
            return try await makeTask(kind: .upload(source: source, request: request), context: pipeline.context)
        case .request(let request):
            return makeRetryableTask(kind: .request(request), context: pipeline.context)
        case .download(let request):
            return try await makeTask(kind: .download(request: request), context: pipeline.context)
        }
    }

    enum ExecutionKind {
        case request(URLRequest)
        case upload(source: UploadSource, request: URLRequest)
        case download(request: URLRequest)
    }

    /// Applies response transforms and stores the response in context.
    func processResponse(_ response: APIResponse, context: RequestContext) async throws -> APIResponse {
        let processed = try await runner.processResponse(response)
        await context.updateResponse(processed)
        return processed
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

    /// Asks retry plugins for a decision.
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        await runner.shouldRetry(snapshot: snapshot, error: error)
    }

    /// Wraps execution with retry evaluation.
    func makeRetryableTask(
        kind: ExecutionKind,
        context: RequestContext
    ) -> RequestTask {
        let responseClosure = { @Sendable () async throws -> APIResponse in
            try await self.performWithRetry(kind: kind, context: context)
        }

        return RequestTask(progress: nil, response: responseClosure)
    }

    /// Executes and retries until a final decision is reached.
    func performWithRetry(
        kind: ExecutionKind,
        context: RequestContext
    ) async throws -> APIResponse {
        var attemptError: Error?

        while true {
            do {
                let task = try await self.makeClientTask(kind: kind)
                let response = try await task.response()
                let processed = try await self.processResponse(response, context: context)
                await self.notifyDidReceive(context: context)
                return processed
            } catch {
                attemptError = error
                await context.updateError(error)

                let snapshot = await context.snapshot()
                let decision = await self.shouldRetry(snapshot: snapshot, error: error)
                switch decision {
                case .retry:
                    await self.runner.willRetry(snapshot: snapshot, error: error, decision: decision)
                    await context.incrementRetryCount()
                    continue
                case .retryAfter(let delay):
                    await self.runner.willRetry(snapshot: snapshot, error: error, decision: decision)
                    await context.incrementRetryCount()
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                case .doNotRetry:
                    await self.notifyDidFail(context: context)
                    throw attemptError ?? error
                }
            }
        }
    }

    /// Wraps the client task and records responses or failures.
    func makeTask(
        kind: ExecutionKind,
        context: RequestContext
    ) async throws -> RequestTask {
        let task = try await makeClientTask(kind: kind)
        let responseClosure = { @Sendable () async throws -> APIResponse in
            do {
                let response = try await task.response()
                let processed = try await self.processResponse(response, context: context)
                await self.notifyDidReceive(context: context)
                return processed
            } catch {
                await context.updateError(error)
                await self.notifyDidFail(context: context)
                throw error
            }
        }

        return RequestTask(progress: task.progress, response: responseClosure)
    }

    /// Calls into the underlying client to create a task.
    func makeClientTask(kind: ExecutionKind) async throws -> RequestTask {
        switch kind {
        case .request(let request):
            let responseClosure = { @Sendable () async throws -> APIResponse in
                try await self.client.request(request)
            }
            return RequestTask(progress: nil, response: responseClosure)
        case .upload(let source, let request):
            return try self.client.upload(request, source: source)
        case .download(let request):
            return try self.client.download(request)
        }
    }

    /// Maps client errors to `APIError` while preserving progress streams.
    func wrapTask(_ task: RequestTask) -> RequestTask {
        let responseClosure = { @Sendable () async throws -> APIResponse in
            do {
                return try await task.response()
            } catch {
                throw self.mapToAPIError(error)
            }
        }

        return RequestTask(progress: task.progress, response: responseClosure)
    }

    /// Ensures errors are surfaced as `APIError`.
    func mapToAPIError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        return .underlying(error)
    }
}

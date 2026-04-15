import Foundation

/// Default provider implementation that runs the request pipeline.
public final class APIProvider: APIProviding, @unchecked Sendable {
    private let client: APIClient
    private let builder: RequestBuilder
    private let runner: PluginRunner
    private let decoder: ResponseDecoder
    private let retryPlugin: RetryPlugin?

    /// Creates a provider with a client, builder, and optional plugins.
    public init(
        client: APIClient,
        builder: RequestBuilder,
        decoder: ResponseDecoder = JSONDecoder(),
        plugins: [any RequestPlugin] = [],
        retryPlugin: RetryPlugin? = nil
    ) {
        self.client = client
        self.builder = builder
        self.runner = PluginRunner(plugins: plugins)
        self.decoder = decoder
        self.retryPlugin = retryPlugin
    }

    /// Executes a request and returns the raw response.
    @discardableResult
    public func request(_ target: any APIRequest) async throws -> APIResponse {
        do {
            let pipeline = try await preparePipeline(for: target)

            let decision = await runner.evaluate(snapshot: pipeline.snapshot)
            if let response = try await handleShortCircuitDecision(decision, context: pipeline.context) {
                return response
            }

            return try await execute(pipeline)
        } catch {
            if error is CancellationError {
                throw error
            }
            throw Self.mapToAPIError(error)
        }
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
}

private extension APIProvider {
    struct Pipeline {
        let target: any APIRequest
        let prepared: any APIRequest
        let request: URLRequest
        let context: RequestContext
        let snapshot: RequestContext.Snapshot
    }

    /// Builds and adapts the request, then notifies observers.
    func preparePipeline(for target: any APIRequest) async throws -> Pipeline {
        let (prepared, adapted) = try await buildRequest(for: target)

        let context = RequestContext(target: prepared)
        await context.updateRequest(adapted)

        await notifyWillSend(context: context)

        let snapshot = await context.snapshot()
        return Pipeline(
            target: target,
            prepared: prepared,
            request: adapted,
            context: context,
            snapshot: snapshot
        )
    }

    /// Executes the request through the retry-capable path.
    func execute(_ pipeline: Pipeline) async throws -> APIResponse {
        try await performWithRetry(target: pipeline.target, request: pipeline.request, context: pipeline.context)
    }

    /// Applies response transforms and stores the response in context.
    func processResponse(_ response: APIResponse, context: RequestContext) async throws -> APIResponse {
        do {
            let processed = try await runner.processResponse(response)
            await context.updateResponse(processed)
            return processed
        } catch {
            await context.updateResponse(response)
            throw error
        }
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

    /// Asks retry plugins for a decision.
    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        guard let retryPlugin else {
            return .doNotRetry
        }
        return await retryPlugin.shouldRetry(snapshot: snapshot, error: error)
    }

    /// Executes and retries until a final decision is reached.
    func performWithRetry(
        target: any APIRequest,
        request: URLRequest,
        context: RequestContext
    ) async throws -> APIResponse {
        var attemptError: Error?
        var currentRequest = request

        while !Task.isCancelled {
            do {
                let response = try await self.client.request(currentRequest)
                let processed = try await self.processResponse(response, context: context)
                await self.notifyDidReceive(context: context)
                return processed
            } catch {
                if error is CancellationError {
                    throw error
                }
                attemptError = error
                await context.updateError(error)
                if let response = Self.response(from: error) {
                    await context.updateResponse(response)
                }

                let snapshot = await context.snapshot()
                let decision = await self.shouldRetry(snapshot: snapshot, error: error)
                switch decision {
                case .retry:
                    await retryPlugin?.willRetry(snapshot: snapshot, error: error, decision: decision)
                    await context.incrementRetryCount()
                    currentRequest = try await prepareRetryRequest(
                        target: target,
                        current: currentRequest,
                        context: context
                    )
                    let retryDecision = await runner.evaluate(snapshot: context.snapshot())
                    if let shortCircuitResponse = try await handleShortCircuitDecision(
                        retryDecision,
                        context: context
                    ) {
                        return shortCircuitResponse
                    }
                    continue
                case let .retryAfter(delay):
                    await retryPlugin?.willRetry(snapshot: snapshot, error: error, decision: decision)
                    await context.incrementRetryCount()
                    try await Task.sleep(for: .seconds(delay))
                    currentRequest = try await prepareRetryRequest(
                        target: target,
                        current: currentRequest,
                        context: context
                    )
                    let retryDecision = await runner.evaluate(snapshot: context.snapshot())
                    if let shortCircuitResponse = try await handleShortCircuitDecision(
                        retryDecision,
                        context: context
                    ) {
                        return shortCircuitResponse
                    }
                    continue
                case .doNotRetry:
                    await self.notifyDidFail(context: context)
                    throw attemptError ?? error
                }
            }
        }
        throw CancellationError()
    }

    func prepareRetryRequest(
        target: any APIRequest,
        current: URLRequest,
        context: RequestContext
    ) async throws -> URLRequest {
        guard let retryPlugin else {
            return current
        }
        let adapted: URLRequest
        switch retryPlugin.policy {
        case .reuseRequest:
            adapted = current
        case .rebuildRequest:
            (_, adapted) = try await buildRequest(for: target)
        }
        await context.resetForRetry(request: adapted)
        await notifyWillSend(context: context)
        return adapted
    }

    func buildRequest(for target: any APIRequest) async throws -> (any APIRequest, URLRequest) {
        let prepared = try await runner.prepareRequest(target)
        let built = try builder.build(prepared)
        let adapted = try await runner.adaptRequest(built)
        return (prepared, adapted)
    }

    func handleShortCircuitDecision(
        _ decision: ShortCircuitDecision,
        context: RequestContext
    ) async throws -> APIResponse? {
        switch decision {
        case let .hitResult(response, _):
            let processed = try await self.processResponse(response, context: context)
            await self.notifyDidReceive(context: context)
            return processed
        case let .hitError(error, _):
            await context.updateError(error)
            await self.notifyDidFail(context: context)
            throw error
        case .miss:
            return nil
        }
    }

    /// Ensures errors are surfaced as `APIError`.
    static func mapToAPIError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        return .underlying(error, response: nil)
    }

    static func response(from error: Error) -> APIResponse? {
        guard case let APIError.underlying(_, response) = error else {
            return nil
        }
        return response
    }
}

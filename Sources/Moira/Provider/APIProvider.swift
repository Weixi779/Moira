import Foundation

public final class APIProvider: APIProviding, @unchecked Sendable {
    private let client: APIClient
    private let builder: RequestBuilder
    private let runner: PluginRunner

    public init(
        client: APIClient,
        builder: RequestBuilder,
        plugins: [any RequestPlugin] = []
    ) {
        self.client = client
        self.builder = builder
        self.runner = PluginRunner(plugins: plugins)
    }

    public func request(_ target: any APIRequest) async throws -> APIResponse {
        let task = try await requestTask(target)
        return try await task.response()
    }

    public func request<T: Decodable>(
        _ target: any APIRequest,
        decoder: ResponseDecoder
    ) async throws -> T {
        let response = try await request(target)
        return try decoder.decode(T.self, from: response.data)
    }

    public func requestTask(_ target: any APIRequest) async throws -> RequestTask {
        let prepared = try await runner.prepareRequest(target)

        let built = try builder.build(prepared)
        let adapted = try await runner.adaptRequest(built)

        let context = RequestContext(target: prepared)
        await context.updateRequest(adapted)

        let snapshot = await context.snapshot()
        await runner.willSend(snapshot: snapshot)

        let shortCircuit = await runner.evaluate(snapshot: snapshot)
        if case .miss = shortCircuit {
        } else {
            switch shortCircuit {
            case .hitResult(let response, _):
                let responseClosure = { @Sendable () async throws -> APIResponse in
                    let processed = try await self.processResponse(response, context: context)
                    await self.notifyDidReceive(context: context)
                    return processed
                }
                return RequestTask(progress: nil, response: responseClosure)
            case .hitError(let error, _):
                let responseClosure = { @Sendable () async throws -> APIResponse in
                    await context.updateError(error)
                    await self.notifyDidFail(context: context)
                    throw error
                }
                return RequestTask(progress: nil, response: responseClosure)
            case .miss:
                break
            }
        }

        if case .upload(let source) = prepared.payload.body {
            return try await makeTask(
                kind: .upload(source: source, request: adapted),
                context: context
            )
        }

        return makeRetryableTask(
            kind: .request(adapted),
            context: context
        )
    }
}

private extension APIProvider {
    enum ExecutionKind {
        case request(URLRequest)
        case upload(source: UploadSource, request: URLRequest)
        case download(request: URLRequest)
    }

    func processResponse(_ response: APIResponse, context: RequestContext) async throws -> APIResponse {
        let processed = try await runner.processResponse(response)
        await context.updateResponse(processed)
        return processed
    }

    func notifyDidReceive(context: RequestContext) async {
        let snapshot = await context.snapshot()
        await runner.didReceive(snapshot: snapshot)
    }

    func notifyDidFail(context: RequestContext) async {
        let snapshot = await context.snapshot()
        await runner.didFail(snapshot: snapshot)
    }

    func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        await runner.shouldRetry(snapshot: snapshot, error: error)
    }

    func makeRetryableTask(
        kind: ExecutionKind,
        context: RequestContext
    ) -> RequestTask {
        let responseClosure = { @Sendable () async throws -> APIResponse in
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
                        await context.incrementRetryCount()
                        continue
                    case .retryAfter(let delay):
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

        return RequestTask(progress: nil, response: responseClosure)
    }

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
}

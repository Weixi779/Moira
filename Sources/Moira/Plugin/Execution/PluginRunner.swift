import Foundation

public struct PluginRunner: Sendable {
    public let transformPlugins: [TransformPlugin]
    public let observerPlugins: [ObserverPlugin]
    public let retryPlugins: [RetryPlugin]
    public let shortCircuitPlugins: [ShortCircuitPlugin]

    public init(plugins: [any RequestPlugin]) {
        self.transformPlugins = plugins.compactMap { $0 as? TransformPlugin }
        self.observerPlugins = plugins.compactMap { $0 as? ObserverPlugin }
        self.retryPlugins = plugins.compactMap { $0 as? RetryPlugin }
        self.shortCircuitPlugins = plugins.compactMap { $0 as? ShortCircuitPlugin }
    }

    public var hasRetryPlugins: Bool { !retryPlugins.isEmpty }
}

extension PluginRunner: TransformPlugin {
    public func prepareRequest(_ request: any APIRequest) async throws -> any APIRequest {
        var prepared = request
        for plugin in transformPlugins {
            prepared = try await plugin.prepareRequest(prepared)
        }
        return prepared
    }

    public func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
        var adapted = request
        for plugin in transformPlugins {
            adapted = try await plugin.adaptRequest(adapted)
        }
        return adapted
    }

    public func processResponse(_ response: APIResponse) async throws -> APIResponse {
        var processed = response
        for plugin in transformPlugins {
            processed = try await plugin.processResponse(processed)
        }
        return processed
    }
}

extension PluginRunner: ObserverPlugin {
    public func willSend(snapshot: RequestContext.Snapshot) async {
        await withTaskGroup(of: Void.self) { group in
            for plugin in observerPlugins {
                group.addTask {
                    await plugin.willSend(snapshot: snapshot)
                }
            }
        }
    }

    public func didReceive(snapshot: RequestContext.Snapshot) async {
        await withTaskGroup(of: Void.self) { group in
            for plugin in observerPlugins {
                group.addTask {
                    await plugin.didReceive(snapshot: snapshot)
                }
            }
        }
    }

    public func didFail(snapshot: RequestContext.Snapshot) async {
        await withTaskGroup(of: Void.self) { group in
            for plugin in observerPlugins {
                group.addTask {
                    await plugin.didFail(snapshot: snapshot)
                }
            }
        }
    }
}

extension PluginRunner: RetryPlugin {
    public func shouldRetry(snapshot: RequestContext.Snapshot, error: Error) async -> RetryDecision {
        for plugin in retryPlugins {
            let decision = await plugin.shouldRetry(snapshot: snapshot, error: error)
            if case .doNotRetry = decision {
                continue
            }
            return decision
        }
        return .doNotRetry
    }

    public func willRetry(snapshot: RequestContext.Snapshot, error: Error, decision: RetryDecision) async {
        for plugin in retryPlugins {
            await plugin.willRetry(snapshot: snapshot, error: error, decision: decision)
        }
    }
}

extension PluginRunner: ShortCircuitPlugin {
    public func evaluate(snapshot: RequestContext.Snapshot) async -> ShortCircuitDecision {
        for plugin in shortCircuitPlugins {
            let decision = await plugin.evaluate(snapshot: snapshot)
            if case .miss = decision {
                continue
            }
            return decision
        }
        return .miss
    }
}

import Foundation

/// Executes plugin chains for each plugin role.
public struct PluginRunner: Sendable {
    /// Transform plugins applied in order.
    public let transformPlugins: [TransformPlugin]
    /// Observer plugins executed concurrently.
    public let observerPlugins: [ObserverPlugin]

    public init(plugins: [any RequestPlugin]) {
        self.transformPlugins = plugins.compactMap { $0 as? TransformPlugin }
        self.observerPlugins = plugins.compactMap { $0 as? ObserverPlugin }
    }
}

extension PluginRunner: TransformPlugin {
    /// Applies `prepareRequest` across all transform plugins in order.
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
    /// Broadcasts `willSend` concurrently to observers.
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

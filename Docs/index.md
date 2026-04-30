# Moira Documentation

Moira is a lightweight async/await networking layer for Swift projects that want Moya-style API modeling, composable request building, and a replaceable `URLSession`-based provider.

Use this index as the entry point for the English documentation. Chinese documentation is available at [Docs/zh/index.md](zh/index.md).

## Start Here

- [Getting Started](Getting-Started.md): install Moira, create an `APIProvider`, and make your first typed request.
- [Core Types](Core-Types.md): understand `APIRequest`, `RequestPayload`, `RequestExecution`, `APIResponse`, and `APIError`.
- [Request Building](Request-Building.md): see how `URLRequestBuilder` resolves paths, query items, headers, timeouts, and bodies.

## Migration and Architecture

- [Migration Guide](Migration-Guide.md): migrate to the current public API baseline.
- [Architecture](Architecture.md): understand the request lifecycle and extension boundaries.
- [Service Layer Guidance](Service-Layer.md): keep Moira in the networking layer and put business mocking above it.

## Extension Points

- [Plugins](Plugins.md): use transform, validation, and observer plugins.
- [Clients](Clients.md): work with `URLSessionClient`, optional client adapters, and custom transport clients.

## Related Entry Points

- [README](../README.md)
- [中文 README](../README.zh.md)
- [中文文档入口](zh/index.md)

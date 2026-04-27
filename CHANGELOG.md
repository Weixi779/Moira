# Changelog

## v1.9.0 - First Stable Public Release

`v1.9.0` is the first stable public release of Moira. It follows the internal
stabilization series ending at `internal/v1.8.0` and establishes the public 1.x
API baseline.

### Highlights

- Added a Foundation-only `URLSessionClient` in the core `Moira` product.
- Split Alamofire support into the separate `MoiraAlamofire` product.
- Split regular request transport and upload transport into `APIClient` and
  `APIUploadClient`.
- Added execution-based upload dispatch through `APIRequest.execution`.
- Reworked request construction around `URLRequestBuilder` and
  `URLRequestBuilding`.
- Added `ResponseValidationPlugin` for global raw response validation.
- Replaced retry plugins with provider-level `RetryStrategy`.
- Added explicit retry decisions with `.reuseRequest` and `.rebuildRequest`
  behavior.
- Clarified request lifecycle observation through `RequestSnapshot`.
- Added service-layer guidance for application-level dependency injection and
  mocking.

### Breaking Changes Since v0.4.1

- `APIRequest` conformers must now provide `execution`.
- `APIClient` is request-only. Upload support now lives in `APIUploadClient`.
- Uploads are modeled through `RequestExecution.upload(UploadSource)` and
  `APIProvider.uploadTask(_:)`.
- The old request-task and download surfaces were removed from the first stable
  API.
- `RequestBuilder` was renamed and reshaped as `URLRequestBuilder`.
- `RequestPayload` now uses static factories and chaining helpers instead of
  the previous verbose construction API.
- `ShortCircuitPlugin` was removed. Provider-level stubbing and short-circuiting
  are intentionally not part of the v1.9.0 API.
- Retry is no longer configured as a request plugin. Use `RetryStrategy` on
  `APIProvider`.
- Response validation is separated from request transformation. Use
  `ResponseValidationPlugin` for raw response gates.
- Unknown errors from custom clients, plugins, and validation are propagated
  unchanged instead of always being wrapped by `APIError.underlying`.
- Alamofire-backed transport now requires importing `MoiraAlamofire`.

### Migration

See [Docs/Migration-Guide.md](Docs/Migration-Guide.md).


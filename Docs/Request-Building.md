# Request Building

Moira provides a complete flow for assembling `URLRequest`s. The goal is to make request building API-like and semantic without forcing a specific architecture. It stays close to native `URLRequest` composition, favors simple reuse, and models only the most common HTTP concepts even if there are multiple pieces.

`URLRequestBuilder` converts `APIRequest` into `URLRequest` with a fixed, predictable set of rules.

## URL resolution

- Uses `target.baseURL` if present, otherwise the provider base URL.
- `path` is resolved relative to the base URL.
- `payload.query` becomes URL query items.

## Headers and timeout

- `headers` are applied as-is.
- `timeout` maps to `URLRequest.timeoutInterval`.
- `Content-Type` is only set when missing.

## Body encoding

`RequestPayload.Body` is encoded as follows:

- `none`: no body
- `json`: encoded by `JSONEncodable` using `JSONEncoder`
- `urlEncodedForm`: `application/x-www-form-urlencoded; charset=utf-8`
- `data`: `application/octet-stream`
- `upload`: multipart boundaries are set by the client

## Content-Type behavior

- JSON: `application/json`
- URL-encoded form: `application/x-www-form-urlencoded; charset=utf-8`
- Raw data: `application/octet-stream`
- Multipart: not set in the builder

## Errors

Invalid paths are mapped to `APIError.requestBuildingFailed`.

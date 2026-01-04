# Request Building

`RequestBuilder` converts `APIRequest` into `URLRequest`.

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
- `json`: encoded by `JSONEncoder`
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

# Lifecycle and Execution Model

Moira's architecture is centered on assembling `URLRequest`s. The pipeline is intentionally close to native request composition, with semantic steps that map to common HTTP concerns rather than a prescriptive app architecture.

Moira follows a fixed pipeline for every request, so plugin behavior stays predictable.

## Pipeline

```
prepare -> build -> adapt -> willSend
  -> execute -> process -> didReceive
  -> on error: shouldRetry? -> willRetry -> retry or didFail
```

## Retry

- Retry decision is evaluated after transport or raw response processing failure.
- Each retry decision chooses whether to rebuild or reuse the request before sending again.
- Request preparation, building, adaptation, and typed decoding failures are not retried.
- `willSend` runs for each retry attempt after the request is rebuilt or reused.
- `willRetry` is fired before the next attempt.
- Final failure triggers `didFail` once.
- Uploads and downloads are not retried by default.

## Observability

- Observers read `RequestContext.Snapshot` only.
- Observer plugins run concurrently.

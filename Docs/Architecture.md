# Lifecycle and Execution Model

Moira follows a fixed pipeline for every request, so plugin behavior stays predictable.

## Pipeline

```
prepare -> build -> adapt -> willSend
  -> shortCircuit? -> execute -> process -> didReceive
  -> on error: shouldRetry? -> willRetry -> retry or didFail
```

## Short-circuit

- Evaluated after `willSend`.
- First hit returns immediately.
- Hit result triggers `didReceive`.
- Hit error triggers `didFail`.

## Retry

- Retry decision is evaluated after a failure.
- Each retry re-enters the client execution path.
- `willRetry` is fired before the next attempt.
- Final failure triggers `didFail` once.

## Observability

- Observers read `RequestContext.Snapshot` only.
- Observer plugins run concurrently.

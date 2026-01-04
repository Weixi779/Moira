# Repository Guidelines

## Project Scope
- Moira is the active Swift package in this repo.

## Structure
- Source code: `Sources/Moira/`
- Tests: `Tests/MoiraTests/`
- Docs live in `Docs/` (English) and `Docs/zh/` (Chinese).

## Build & Test
- `swift build`
- `swift test`

## Testing Notes
- Tests use Swift Testing (`import Testing`).
- Integration tests hit `https://httpbin.org` and require network access.
- Prefer unit tests for APIProvider, RequestBuilder, and plugins when possible.

## Conventions
- Swift tools version 5.9; minimum platforms iOS 16 / macOS 13.
- 4-space indentation; prefer protocol-oriented design and async/await.
- Keep APIs small and composable; avoid large enums that block plugin evolution.

## Docs Workflow
- Keep docs in sync when changing public APIs.

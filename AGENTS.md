# Repository Guidelines

## Project Scope
- Moira is the active Swift package in this repo.

## Structure
- Source code: `Sources/Moira/`
- Tests: `Tests/MoiraTests/`
- Design notes and decisions: `docs/01.md`–`docs/07-decoder-and-shortcircuit.md`

## Build & Test
- `swift build`
- `swift test`

## Conventions
- Swift tools version 5.9; minimum platforms iOS 16 / macOS 13.
- 4-space indentation; prefer protocol-oriented design and async/await.
- Keep APIs small and composable; avoid large enums that block plugin evolution.

## Docs Workflow
- Use `docs/06-issues.md` as the question pool.
- Record confirmed decisions in `docs/07-decoder-and-shortcircuit.md`.
- Keep docs in sync when changing public APIs.

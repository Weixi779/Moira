# Service Layer Guidance

Moira intentionally stops at the request/provider boundary. This document describes the recommended way to build an application-facing service layer on top of it.

## Core idea

Define business services in application code and let each service choose the narrowest network capability it actually needs.

- Use `any APIRequesting` when the service only performs regular requests.
- Use `any APIProviding` when the service also performs uploads.

Moira does not require a shared `APIService` base protocol for this pattern to work.

## Request-only service

```swift
protocol UserServicing: Sendable {
    func profile(id: String) async throws -> User
}

struct UserService: UserServicing {
    let requester: any APIRequesting

    func profile(id: String) async throws -> User {
        try await requester.request(UserAPI.profile(id: id))
    }
}
```

This keeps the dependency surface small and makes the service easy to substitute in tests.

## Service with upload support

```swift
protocol AvatarServicing: Sendable {
    func profile(id: String) async throws -> User
    func uploadAvatar(data: Data) async throws -> UploadReceipt
}

struct AvatarService: AvatarServicing {
    let provider: any APIProviding

    func profile(id: String) async throws -> User {
        try await provider.request(UserAPI.profile(id: id))
    }

    func uploadAvatar(data: Data) async throws -> UploadReceipt {
        let task: UploadTask<UploadReceipt> = try await provider.uploadTask(
            UserAPI.uploadAvatar(data: data)
        )
        return try await task.response()
    }
}
```

If a service needs upload capability, depending on `APIProviding` is the honest model.

## Mocking strategy

Mock at the service boundary, not at the raw transport boundary.

```swift
struct MockUserService: UserServicing {
    let result: Result<User, Error>

    func profile(id: String) async throws -> User {
        try result.get()
    }
}
```

This matches how application code consumes the API and avoids rebuilding `Data` or `APIResponse` values just to reach a decoded result.

## Why Moira does not ship `APIService`

A built-in `APIService` abstraction would either:

- force every service to depend on a capability set that is too wide, or
- be too narrow and fail once uploads or other execution modes enter the picture

The library therefore leaves service composition to application code and focuses on keeping `APIRequest` and `APIProvider` easy to build on top of.

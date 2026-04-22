# Service 层建议

Moira 有意停在 request/provider 这一层。这份文档说明在其之上如何组织更面向业务的 service。

## 核心思路

业务 service 由应用自己定义，并由每个 service 选择自己真正需要的最小网络能力。

- 如果只做普通请求，依赖 `any APIRequesting`
- 如果同时包含上传，依赖 `any APIProviding`

Moira 不要求你为此再套一层统一的 `APIService` 基类或强制协议。

## 只做请求的 service

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

这种写法依赖面最小，也非常适合在测试中替换实现。

## 同时包含上传能力的 service

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

如果一个 service 真实需要 upload 能力，那么依赖 `APIProviding` 就是正确建模，而不是负担。

## Mock 策略

mock 应放在 service 边界，而不是原始传输边界。

```swift
struct MockUserService: UserServicing {
    let result: Result<User, Error>

    func profile(id: String) async throws -> User {
        try result.get()
    }
}
```

这更符合业务代码的消费方式，也避免为了拿到一个解码结果还要手工构造 `Data` 或 `APIResponse`。

## 为什么 Moira 不内建 `APIService`

如果框架内建一个统一的 `APIService` 抽象，它通常只会落到两种结果之一：

- 依赖能力过宽，所有 service 都被迫拿到更多能力
- 依赖能力过窄，一旦出现 upload 等执行模式就不够用

因此，Moira 选择把 service 的组织方式留给业务层，只保证 `APIRequest` 和 `APIProvider` 足够清晰、足够容易作为底座来使用。

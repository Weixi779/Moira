import Foundation

public actor RequestContext {
    public let id: UUID
    public let target: any APIRequest
    public let startTime: Date

    public private(set) var request: URLRequest?
    public private(set) var response: APIResponse?
    public private(set) var error: Error?
    public private(set) var retryCount: Int

    public init(target: any APIRequest) {
        self.id = UUID()
        self.target = target
        self.startTime = Date()
        self.retryCount = 0
    }

    public func updateRequest(_ request: URLRequest) {
        self.request = request
    }

    public func updateResponse(_ response: APIResponse) {
        self.response = response
    }

    public func updateError(_ error: Error) {
        self.error = error
    }

    public func incrementRetryCount() {
        retryCount += 1
    }

    public func snapshot() -> Snapshot {
        Snapshot(
            id: id,
            target: target,
            startTime: startTime,
            request: request,
            response: response,
            error: error,
            retryCount: retryCount
        )
    }

    public struct Snapshot: @unchecked Sendable {
        public let id: UUID
        public let target: any APIRequest
        public let startTime: Date
        public let request: URLRequest?
        public let response: APIResponse?
        public let error: Error?
        public let retryCount: Int
    }
}

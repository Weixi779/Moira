import Foundation

/// URLSession-backed implementation of `APIClient` and `APIUploadClient`.
public final class URLSessionClient: APIClient, APIUploadClient, @unchecked Sendable {
    private let session: URLSession
    private let delegate: URLSessionClientDelegate
    private let fileManager: FileManager

    /// Creates a client using the provided URLSession configuration.
    public init(
        configuration: URLSessionConfiguration = .default,
        delegateQueue: OperationQueue? = nil,
        fileManager: FileManager = .default
    ) {
        let delegate = URLSessionClientDelegate()
        self.delegate = delegate
        self.fileManager = fileManager
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: delegateQueue
        )
    }

    /// Executes a data request and returns an `APIResponse`.
    public func request(_ request: URLRequest) async throws -> APIResponse {
        do {
            let (data, response) = try await session.data(for: request)
            return Self.makeResponse(data: data, response: response as? HTTPURLResponse)
        } catch {
            throw APIError.underlying(error, response: nil)
        }
    }

    public func upload(
        _ request: URLRequest,
        source: UploadSource
    ) throws -> UploadTask<APIResponse> {
        let upload = try makeUpload(request, source: source)
        let responseBox = ResponseBox<APIResponse>()
        let (progressStream, progressContinuation) = AsyncStream<UploadProgress>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let task = upload.makeTask(using: session) { data, response, error in
            self.delegate.unregister(taskIdentifier: upload.taskIdentifier)
            progressContinuation.finish()
            upload.cleanup()

            let apiResponse = Self.makeResponse(
                data: data,
                response: response as? HTTPURLResponse
            )

            if let error {
                responseBox.complete(.failure(APIError.underlying(error, response: apiResponse)))
            } else {
                responseBox.complete(.success(apiResponse))
            }
        }

        upload.assign(taskIdentifier: task.taskIdentifier)
        delegate.register(taskIdentifier: task.taskIdentifier, continuation: progressContinuation)
        progressContinuation.onTermination = { @Sendable _ in
            task.cancel()
        }
        task.resume()

        let responseClosure = { @Sendable () async throws -> APIResponse in
            try await responseBox.wait {
                task.cancel()
            }
        }
        return UploadTask(progress: progressStream, response: responseClosure)
    }
}

private extension URLSessionClient {
    static func makeResponse(data: Data?, response: HTTPURLResponse?) -> APIResponse {
        let headers = normalizeHeaders(response?.allHeaderFields ?? [:])
        let statusCode = response?.statusCode ?? -1
        return APIResponse(
            statusCode: statusCode,
            data: data ?? Data(),
            headers: headers,
            response: response
        )
    }

    /// Normalized headers for logging/inspection; multi-value semantics are not preserved.
    static func normalizeHeaders(_ headers: [AnyHashable: Any]) -> [String: String] {
        headers.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String else { return }
            result[key] = String(describing: entry.value)
        }
    }

    func makeUpload(_ request: URLRequest, source: UploadSource) throws -> URLSessionUpload {
        switch source {
        case let .data(data):
            return URLSessionUpload(request: request, body: .data(data))
        case let .file(url):
            return URLSessionUpload(request: request, body: .file(url, shouldRemove: false))
        case let .multipart(parts):
            return try makeMultipartUpload(request, parts: parts)
        }
    }

    func makeMultipartUpload(_ request: URLRequest, parts: [MultipartFormPart]) throws -> URLSessionUpload {
        let boundary = "moira.boundary.\(UUID().uuidString)"
        var multipartRequest = request
        multipartRequest.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("Moira", isDirectory: true)
            .appendingPathComponent("MultipartFormData", isDirectory: true)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileURL = directoryURL.appendingPathComponent(UUID().uuidString)
        do {
            try MultipartFormEncoder(boundary: boundary).write(parts, to: fileURL)
        } catch {
            try? fileManager.removeItem(at: fileURL)
            throw error
        }

        return URLSessionUpload(
            request: multipartRequest,
            body: .file(fileURL, shouldRemove: true)
        )
    }
}

private final class URLSessionUpload: @unchecked Sendable {
    enum Body {
        case data(Data)
        case file(URL, shouldRemove: Bool)
    }

    let request: URLRequest
    let body: Body

    private let lock = NSLock()
    private var storedTaskIdentifier: Int?

    var taskIdentifier: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedTaskIdentifier ?? -1
    }

    init(request: URLRequest, body: Body) {
        self.request = request
        self.body = body
    }

    func assign(taskIdentifier: Int) {
        lock.lock()
        storedTaskIdentifier = taskIdentifier
        lock.unlock()
    }

    func makeTask(
        using session: URLSession,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionUploadTask {
        switch body {
        case let .data(data):
            return session.uploadTask(
                with: request,
                from: data,
                completionHandler: completionHandler
            )
        case let .file(url, _):
            return session.uploadTask(
                with: request,
                fromFile: url,
                completionHandler: completionHandler
            )
        }
    }

    func cleanup() {
        guard case let .file(url, shouldRemove) = body, shouldRemove else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

private final class URLSessionClientDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [Int: AsyncStream<UploadProgress>.Continuation] = [:]

    func register(
        taskIdentifier: Int,
        continuation: AsyncStream<UploadProgress>.Continuation
    ) {
        lock.lock()
        continuations[taskIdentifier] = continuation
        lock.unlock()
    }

    func unregister(taskIdentifier: Int) {
        lock.lock()
        continuations[taskIdentifier] = nil
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let continuation = continuation(for: task.taskIdentifier)
        continuation?.yield(
            UploadProgress(
                completedBytes: totalBytesSent,
                totalBytes: totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : nil
            )
        )
    }

    private func continuation(for taskIdentifier: Int) -> AsyncStream<UploadProgress>.Continuation? {
        lock.lock()
        defer { lock.unlock() }
        return continuations[taskIdentifier]
    }
}

private final class ResponseBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, any Error>?
    private var continuations: [CheckedContinuation<Value, any Error>] = []

    func wait(onCancel: @escaping @Sendable () -> Void) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let result {
                    lock.unlock()
                    continuation.resume(with: result)
                } else {
                    continuations.append(continuation)
                    lock.unlock()
                }
            }
        } onCancel: {
            onCancel()
        }
    }

    func complete(_ result: Result<Value, any Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuations = self.continuations
        self.continuations = []
        lock.unlock()

        for continuation in continuations {
            continuation.resume(with: result)
        }
    }
}

private struct MultipartFormEncoder {
    private enum EncodingCharacters {
        static let crlf = "\r\n"
    }

    let boundary: String

    func write(_ parts: [MultipartFormPart], to fileURL: URL) throws {
        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw APIError.requestBuildingFailed("Failed to create multipart output stream.")
        }

        outputStream.open()
        defer { outputStream.close() }

        for (index, part) in parts.enumerated() {
            try write(boundaryData(isInitial: index == 0), to: outputStream)
            try write(headersData(for: part), to: outputStream)
            try write(part.data, to: outputStream)
        }

        if !parts.isEmpty {
            try write(finalBoundaryData(), to: outputStream)
        }

        if let error = outputStream.streamError {
            throw APIError.requestBuildingFailed("Failed to write multipart body: \(error.localizedDescription)")
        }
    }

    private func boundaryData(isInitial: Bool) -> Data {
        let text = isInitial
            ? "--\(boundary)\(EncodingCharacters.crlf)"
            : "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
        return Data(text.utf8)
    }

    private func finalBoundaryData() -> Data {
        Data("\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)".utf8)
    }

    private func headersData(for part: MultipartFormPart) -> Data {
        var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
        if let fileName = part.fileName {
            disposition += "; filename=\"\(fileName)\""
        }

        var text = disposition + EncodingCharacters.crlf
        if let mimeType = part.mimeType {
            text += "Content-Type: \(mimeType)\(EncodingCharacters.crlf)"
        } else if part.fileName != nil {
            text += "Content-Type: application/octet-stream\(EncodingCharacters.crlf)"
        }
        text += EncodingCharacters.crlf

        return Data(text.utf8)
    }

    private func write(_ data: Data, to outputStream: OutputStream) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard var pointer = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            var bytesRemaining = data.count

            while bytesRemaining > 0 {
                let bytesWritten = outputStream.write(pointer, maxLength: bytesRemaining)
                if bytesWritten < 0 {
                    let description = outputStream.streamError?.localizedDescription ?? "Unknown stream error."
                    throw APIError.requestBuildingFailed("Failed to write multipart body: \(description)")
                }
                if bytesWritten == 0 {
                    throw APIError.requestBuildingFailed("Failed to write multipart body.")
                }

                bytesRemaining -= bytesWritten
                pointer = pointer.advanced(by: bytesWritten)
            }
        }
    }
}

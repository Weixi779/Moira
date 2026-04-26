import Alamofire
import Foundation

/// Alamofire-backed implementation of `APIClient` and `APIUploadClient`.
public final class AlamofireClient: APIClient, APIUploadClient, @unchecked Sendable {
    private let session: Session

    /// Creates a client using the provided Alamofire session.
    public init(session: Session = .default) {
        self.session = session
    }

    /// Executes a data request and returns an `APIResponse`.
    public func request(_ request: URLRequest) async throws -> APIResponse {
        let dataResponse = await session.request(request).serializingData().response

        if let error = dataResponse.error {
            let response = Self.makeResponse(
                data: dataResponse.data,
                response: dataResponse.response
            )
            throw APIError.underlying(error, response: response)
        }

        return Self.makeResponse(
            data: dataResponse.data,
            response: dataResponse.response
        )
    }

    public func upload(
        _ request: URLRequest,
        source: UploadSource
    ) throws -> UploadTask<APIResponse> {
        let (dataRequest, progressStream, continuation) = try makeUploadRequest(request, source: source)
        let responseClosure = { @Sendable () async throws -> APIResponse in
            let dataResponse = await dataRequest.serializingData().response
            continuation.finish()

            if let error = dataResponse.error {
                let response = Self.makeResponse(
                    data: dataResponse.data,
                    response: dataResponse.response
                )
                throw APIError.underlying(error, response: response)
            }

            return Self.makeResponse(
                data: dataResponse.data,
                response: dataResponse.response
            )
        }
        return UploadTask(progress: progressStream, response: responseClosure)
    }
}

private extension AlamofireClient {
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

    func makeUploadRequest(
        _ request: URLRequest,
        source: UploadSource
    ) throws -> (DataRequest, AsyncStream<UploadProgress>, AsyncStream<UploadProgress>.Continuation) {
        let (stream, continuation) = AsyncStream<UploadProgress>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let dataRequest: DataRequest
        switch source {
        case let .data(data):
            dataRequest = session.upload(data, with: request)
        case let .file(url):
            dataRequest = session.upload(url, with: request)
        case let .multipart(parts):
            var mutableRequest = request
            // Allow Alamofire to set the multipart boundary.
            mutableRequest.setValue(nil, forHTTPHeaderField: "Content-Type")
            dataRequest = session.upload(multipartFormData: { form in
                for part in parts {
                    switch (part.fileName, part.mimeType) {
                    case let (fileName?, mimeType?):
                        form.append(part.data, withName: part.name, fileName: fileName, mimeType: mimeType)
                    case let (fileName?, nil):
                        form.append(part.data, withName: part.name, fileName: fileName, mimeType: "application/octet-stream")
                    case let (nil, mimeType?):
                        form.append(part.data, withName: part.name, mimeType: mimeType)
                    case (nil, nil):
                        form.append(part.data, withName: part.name)
                    }
                }
            }, with: mutableRequest)
        }

        continuation.onTermination = { @Sendable _ in
            dataRequest.cancel()
        }

        dataRequest.uploadProgress { progress in
            let update = UploadProgress(
                completedBytes: progress.completedUnitCount,
                totalBytes: progress.totalUnitCount > 0 ? progress.totalUnitCount : nil
            )
            continuation.yield(update)
        }

        return (dataRequest, stream, continuation)
    }
}

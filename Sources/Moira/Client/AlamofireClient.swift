import Alamofire
import Foundation

public final class AlamofireClient: APIClient {
    private let session: Session

    public init(session: Session = .default) {
        self.session = session
    }

    public func request(_ request: URLRequest) async throws -> APIResponse {
        let dataResponse = await session.request(request).serializingData().response

        if let error = dataResponse.error {
            throw APIError.underlying(error)
        }

        let data = dataResponse.data ?? Data()
        let httpResponse = dataResponse.response
        let headers = Self.normalizeHeaders(httpResponse?.allHeaderFields ?? [:])
        let statusCode = httpResponse?.statusCode ?? -1

        return APIResponse(
            statusCode: statusCode,
            data: data,
            headers: headers,
            response: httpResponse
        )
    }

    public func upload(
        _ request: URLRequest,
        source: UploadSource
    ) throws -> RequestTask {
        let (request, progressStream, continuation) = try makeUploadRequest(request, source: source)
        let responseClosure = { @Sendable () async throws -> APIResponse in
            let dataResponse = await request.serializingData().response
            continuation.finish()

            if let error = dataResponse.error {
                throw APIError.underlying(error)
            }

            let data = dataResponse.data ?? Data()
            let httpResponse = dataResponse.response
            let headers = Self.normalizeHeaders(httpResponse?.allHeaderFields ?? [:])
            let statusCode = httpResponse?.statusCode ?? -1

            return APIResponse(
                statusCode: statusCode,
                data: data,
                headers: headers,
                response: httpResponse
            )
        }
        return RequestTask(progress: progressStream, response: responseClosure)
    }

    public func download(
        _ request: URLRequest
    ) throws -> RequestTask {
        let (stream, continuation) = AsyncStream<RequestProgress>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let download = session.download(request)
        continuation.onTermination = { @Sendable _ in
            download.cancel()
        }
        download.downloadProgress { progress in
            let update = RequestProgress(
                completedBytes: progress.completedUnitCount,
                totalBytes: progress.totalUnitCount > 0 ? progress.totalUnitCount : nil
            )
            continuation.yield(update)
        }

        let responseClosure = { @Sendable () async throws -> APIResponse in
            let response = await download.serializingData().response
            continuation.finish()

            if let error = response.error {
                throw APIError.underlying(error)
            }

            let data = response.value ?? Data()
            let httpResponse = response.response
            let headers = Self.normalizeHeaders(httpResponse?.allHeaderFields ?? [:])
            let statusCode = httpResponse?.statusCode ?? -1

            return APIResponse(
                statusCode: statusCode,
                data: data,
                headers: headers,
                response: httpResponse
            )
        }

        return RequestTask(progress: stream, response: responseClosure)
    }
}

private extension AlamofireClient {
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
    ) throws -> (DataRequest, AsyncStream<RequestProgress>, AsyncStream<RequestProgress>.Continuation) {
        let (stream, continuation) = AsyncStream<RequestProgress>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let dataRequest: DataRequest
        switch source {
        case .data(let data):
            dataRequest = session.upload(data, with: request)
        case .file(let url):
            dataRequest = session.upload(url, with: request)
        case .multipart(let parts):
            dataRequest = session.upload(multipartFormData: { form in
                for part in parts {
                    if let fileName = part.fileName, let mimeType = part.mimeType {
                        form.append(part.data, withName: part.name, fileName: fileName, mimeType: mimeType)
                    } else {
                        form.append(part.data, withName: part.name)
                    }
                }
            }, with: request)
        }

        continuation.onTermination = { @Sendable _ in
            dataRequest.cancel()
        }

        dataRequest.uploadProgress { progress in
            let update = RequestProgress(
                completedBytes: progress.completedUnitCount,
                totalBytes: progress.totalUnitCount > 0 ? progress.totalUnitCount : nil
            )
            continuation.yield(update)
        }

        return (dataRequest, stream, continuation)
    }
}

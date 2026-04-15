import Alamofire
import Foundation

/// Alamofire-backed implementation of `APIClient`.
public final class AlamofireClient: APIClient {
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
}

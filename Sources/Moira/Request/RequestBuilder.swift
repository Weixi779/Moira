import Foundation

/// Builds `URLRequest` instances from `APIRequest` values.
public struct RequestBuilder {
    public let baseURL: URL
    private let encoder = JSONEncoder()

    /// Creates a builder with the base URL used for resolving paths.
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Builds a `URLRequest` by resolving the URL, headers, and body.
    public func build(_ target: any APIRequest) throws -> URLRequest {
        try validateExecution(target)

        let url = try buildURL(for: target)
        var request = URLRequest(url: url)
        request.httpMethod = target.method.rawValue
        request.timeoutInterval = target.timeout
        request.applyHeaders(target.headers)
        try applyBody(target.payload.body, to: &request)
        applyUploadContentType(target.execution, to: &request)
        return request
    }
}

private extension RequestBuilder {
    /// Validates that upload requests do not carry a payload body.
    func validateExecution(_ target: any APIRequest) throws {
        if case .upload = target.execution, case .none = target.payload.body {
            return
        }
        if case .upload = target.execution {
            throw APIError.invalidRequest("Upload requests must use payload.body == .none.")
        }
    }

    /// Sets a default Content-Type for non-multipart upload sources.
    func applyUploadContentType(_ execution: RequestExecution, to request: inout URLRequest) {
        guard case let .upload(source) = execution else { return }
        switch source {
        case .data, .file:
            request.setContentTypeIfNeeded("application/octet-stream")
        case .multipart:
            break
        }
    }

    /// Resolves the final URL with base URL, path, and query items.
    func buildURL(for target: any APIRequest) throws -> URL {
        let resolvedBaseURL = target.baseURL ?? baseURL
        guard var url = URL(string: target.path, relativeTo: resolvedBaseURL) else {
            throw APIError.requestBuildingFailed("Invalid path: \(target.path)")
        }

        if !target.payload.query.isEmpty {
            url.append(queryItems: target.payload.query)
        }
        return url
    }

    /// Encodes the request body and sets the `Content-Type` header if needed.
    func applyBody(_ body: RequestPayload.Body, to request: inout URLRequest) throws {
        switch body {
        case .none:
            break
        case let .json(encodable):
            let data = try encodable.encode(using: encoder)
            request.httpBody = data
            request.setContentTypeIfNeeded("application/json")
        case let .urlEncodedForm(items):
            request.httpBody = items.formEncodedString.data(using: .utf8)
            request.setContentTypeIfNeeded("application/x-www-form-urlencoded; charset=utf-8")
        case let .data(data):
            request.httpBody = data
            request.setContentTypeIfNeeded("application/octet-stream")
        }
    }
}

private extension URLRequest {
    /// Applies additional headers onto a request.
    mutating func applyHeaders(_ headers: [String: String]?) {
        guard let headers else { return }
        for (key, value) in headers {
            setValue(value, forHTTPHeaderField: key)
        }
    }

    /// Sets the content type only when the header is missing.
    mutating func setContentTypeIfNeeded(_ contentType: String) {
        if value(forHTTPHeaderField: "Content-Type") == nil {
            setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
    }
}

private extension [URLQueryItem] {
    /// Encodes query items as `application/x-www-form-urlencoded`.
    var formEncodedString: String {
        var components = URLComponents()
        components.queryItems = self
        return components.percentEncodedQuery ?? ""
    }
}

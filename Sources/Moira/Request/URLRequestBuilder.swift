import Foundation

/// Builds `URLRequest` instances from `APIRequest` values.
public struct URLRequestBuilder: Sendable {
    public let baseURL: URL

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

        try applyBody(target.payload.body, execution: target.execution, to: &request)

        return request
    }
}

// MARK: - Validation

private extension URLRequestBuilder {
    /// Validates that upload requests do not carry a payload body.
    func validateExecution(_ target: any APIRequest) throws {
        switch (target.execution, target.payload.body) {
        case (.upload, .none):
            break
        case (.upload, _):
            throw APIError.invalidRequest("Upload requests must use payload.body == .none.")
        default:
            break
        }
    }
}

// MARK: - URL Resolution

private extension URLRequestBuilder {
    /// Resolves the final URL with base URL, path, and query items.
    func buildURL(for target: any APIRequest) throws -> URL {
        let base = target.baseURL ?? baseURL
        let pathURL = appendingEndpointPath(target.path, to: base)
        return try appendingQuery(target.payload.query, to: pathURL)
    }

    /// Appends an endpoint path onto the base URL path.
    func appendingEndpointPath(_ path: String, to base: URL) -> URL {
        let endpointPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !endpointPath.isEmpty else { return base }
        return base.appendingPathComponent(endpointPath)
    }

    /// Appends payload query items after any existing URL query items.
    func appendingQuery(_ items: [URLQueryItem], to url: URL) throws -> URL {
        guard !items.isEmpty else { return url }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw APIError.requestBuildingFailed("Invalid URL for components: \(url.absoluteString)")
        }

        let baseQueryItems = components.queryItems ?? []
        components.queryItems = baseQueryItems + items

        guard let finalURL = components.url else {
            throw APIError.requestBuildingFailed("Failed to generate URL with query items.")
        }
        return finalURL
    }
}

// MARK: - Request Construction

private extension URLRequestBuilder {
    /// Encodes the request body and sets the `Content-Type` header if needed.
    func applyBody(
        _ body: RequestPayload.Body,
        execution: RequestExecution,
        to request: inout URLRequest
    ) throws {
        request.httpBody = try body.bodyData()

        if let contentType = resolvedContentType(for: body, execution: execution) {
            request.ensureContentType(contentType)
        }
    }

    /// Resolves the preferred `Content-Type` from the body or upload source.
    func resolvedContentType(for body: RequestPayload.Body, execution: RequestExecution) -> String? {
        if let contentType = body.contentType {
            return contentType
        }

        guard case let .upload(source) = execution else { return nil }
        switch source {
        case .data, .file:
            return "application/octet-stream"
        case .multipart:
            return nil
        }
    }
}

// MARK: - RequestPayload.Body Helpers

private extension RequestPayload.Body {
    /// Encodes the request body into raw data.
    func bodyData() throws -> Data? {
        switch self {
        case .none:
            return nil
        case let .json(encodable):
            return try encodable.encode(using: JSONEncoder())
        case let .urlEncodedForm(items):
            return Data(items.formEncodedString.utf8)
        case let .data(data):
            return data
        }
    }

    /// Returns the default `Content-Type` for a request body.
    var contentType: String? {
        switch self {
        case .none:
            return nil
        case .json:
            return "application/json"
        case .urlEncodedForm:
            return "application/x-www-form-urlencoded; charset=utf-8"
        case .data:
            return "application/octet-stream"
        }
    }
}

// MARK: - URLRequest Helpers

private extension URLRequest {
    /// Applies additional headers onto a request.
    mutating func applyHeaders(_ headers: [String: String]?) {
        guard let headers else { return }
        for (key, value) in headers {
            setValue(value, forHTTPHeaderField: key)
        }
    }

    /// Sets the content type only when the header is missing.
    mutating func ensureContentType(_ contentType: String) {
        if value(forHTTPHeaderField: "Content-Type") == nil {
            setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
    }
}

// MARK: - URLQueryItem Helpers

private extension [URLQueryItem] {
    /// Encodes query items as `application/x-www-form-urlencoded`.
    var formEncodedString: String {
        var components = URLComponents()
        components.queryItems = self
        return components.percentEncodedQuery ?? ""
    }
}

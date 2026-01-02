import Foundation

public struct RequestBuilder {
    public let baseURL: URL?
    public let encoder: JSONEncoder

    public init(baseURL: URL? = nil, encoder: JSONEncoder = JSONEncoder()) {
        self.baseURL = baseURL
        self.encoder = encoder
    }

    public func build(_ target: any APIRequest) throws -> URLRequest {
        let baseURL = target.baseURL ?? baseURL
        guard let baseURL else {
            throw APIError.requestBuildingFailed("Missing baseURL for \(target.path)")
        }

        guard let url = URL(string: target.path, relativeTo: baseURL) else {
            throw APIError.requestBuildingFailed("Invalid path: \(target.path)")
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let queryItems = target.payload.query
        if !queryItems.isEmpty {
            if var resolved = components {
                var items = resolved.queryItems ?? []
                items.append(contentsOf: queryItems)
                resolved.queryItems = items
                components = resolved
            }
        }

        guard let finalURL = components?.url else {
            throw APIError.requestBuildingFailed("Failed to build URL for \(target.path)")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = target.method.rawValue
        request.timeoutInterval = target.timeout
        if let headers = target.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        switch target.payload.body {
        case .none:
            break
        case .json(let encodable):
            let data = try encodable.encode(using: encoder)
            request.httpBody = data
            setContentTypeIfNeeded(&request, value: "application/json")
        case .urlEncodedForm(let items):
            let bodyString = formEncodedString(items: items)
            request.httpBody = bodyString.data(using: .utf8)
            setContentTypeIfNeeded(&request, value: "application/x-www-form-urlencoded; charset=utf-8")
        case .data(let data):
            request.httpBody = data
        case .upload:
            break
        }

        return request
    }
}

private func setContentTypeIfNeeded(_ request: inout URLRequest, value: String) {
    if request.value(forHTTPHeaderField: "Content-Type") == nil {
        request.setValue(value, forHTTPHeaderField: "Content-Type")
    }
}

private func formEncodedString(items: [URLQueryItem]) -> String {
    var components = URLComponents()
    components.queryItems = items
    return components.percentEncodedQuery ?? ""
}

public enum APIError: Error, Sendable {
    case requestBuildingFailed(String)
    case responseDecodingFailed(Error)
    case underlying(Error)
}

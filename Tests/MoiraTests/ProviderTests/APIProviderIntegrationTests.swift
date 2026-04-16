import Foundation
import Testing
@testable import Moira

private enum IntegrationConfig {
    static let baseURL: URL = {
        let value = "https://httpbin.org"
        return URL(string: value)!
    }()
}

private struct SimpleRequest: APIRequest {
    let path: String
    let method: RequestMethod
    let payload: RequestPayload
    let execution: RequestExecution
    let baseURL: URL?
    let headers: [String: String]?
    let timeout: TimeInterval

    init(
        path: String,
        method: RequestMethod = .get,
        payload: RequestPayload = .init(),
        execution: RequestExecution = .request,
        baseURL: URL? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) {
        self.path = path
        self.method = method
        self.payload = payload
        self.execution = execution
        self.baseURL = baseURL
        self.headers = headers
        self.timeout = timeout
    }
}

private struct GetResponse: Decodable {
    let args: [String: String]
}

private struct PostResponse: Decodable {
    let json: Payload?
    let data: String
}

private struct Payload: Codable, Equatable {
    let message: String
}

@Suite(.tags(.provider, .integration))
struct APIProviderIntegrationTests {
    @Test("getRequestReturnsArgs")
    func getRequestReturnsArgs() async throws {
        let builder = URLRequestBuilder(baseURL: IntegrationConfig.baseURL)
        let provider = APIProvider(client: AlamofireClient(), builder: builder)
        let request = SimpleRequest(path: "/get", payload: .query("q", "moira"))

        let response: GetResponse = try await provider.request(request)
        #expect(response.args["q"] == "moira")
    }

    @Test("postJSONBodyEchoesJSON")
    func postJSONBodyEchoesJSON() async throws {
        let builder = URLRequestBuilder(baseURL: IntegrationConfig.baseURL)
        let provider = APIProvider(client: AlamofireClient(), builder: builder)
        let request = SimpleRequest(path: "/post", method: .post, payload: .json(Payload(message: "hello")))

        let response: PostResponse = try await provider.request(request)
        #expect(response.json == Payload(message: "hello"))
    }

    @Test("uploadDataEchoesRawBody")
    func uploadDataEchoesRawBody() async throws {
        let builder = URLRequestBuilder(baseURL: IntegrationConfig.baseURL)
        let provider = APIProvider(client: AlamofireClient(), builder: builder)
        let data = Data("raw-body".utf8)
        let request = SimpleRequest(
            path: "/post",
            method: .post,
            execution: .upload(.data(data))
        )

        let task = try await provider.uploadTask(request)
        let response: PostResponse = try await {
            let raw = try await task.response()
            return try JSONDecoder().decode(PostResponse.self, from: raw.data)
        }()
        #expect(response.data == "raw-body")
    }
}

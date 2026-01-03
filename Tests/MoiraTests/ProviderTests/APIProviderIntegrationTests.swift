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
    let baseURL: URL?
    let headers: [String: String]?
    let timeout: TimeInterval

    init(
        path: String,
        method: RequestMethod = .get,
        payload: RequestPayload = .init(),
        baseURL: URL? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) {
        self.path = path
        self.method = method
        self.payload = payload
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
        let builder = RequestBuilder(baseURL: IntegrationConfig.baseURL)
        let provider = APIProvider(client: AlamofireClient(), builder: builder)
        let payload = RequestPayload(query: [
            URLQueryItem(name: "q", value: "moira")
        ])
        let request = SimpleRequest(path: "/get", payload: payload)

        let response: GetResponse = try await provider.request(request, decoder: JSONDecoder())
        #expect(response.args["q"] == "moira")
    }

    @Test("postJSONBodyEchoesJSON")
    func postJSONBodyEchoesJSON() async throws {
        let builder = RequestBuilder(baseURL: IntegrationConfig.baseURL)
        let provider = APIProvider(client: AlamofireClient(), builder: builder)
        let payload = RequestPayload().withJSON(Payload(message: "hello"))
        let request = SimpleRequest(path: "/post", method: .post, payload: payload)

        let response: PostResponse = try await provider.request(request, decoder: JSONDecoder())
        #expect(response.json == Payload(message: "hello"))
    }

    @Test("uploadDataEchoesRawBody")
    func uploadDataEchoesRawBody() async throws {
        let builder = RequestBuilder(baseURL: IntegrationConfig.baseURL)
        let provider = APIProvider(client: AlamofireClient(), builder: builder)
        let data = Data("raw-body".utf8)
        let payload = RequestPayload().withUpload(.data(data))
        let request = SimpleRequest(path: "/post", method: .post, payload: payload)

        let response: PostResponse = try await provider.request(request, decoder: JSONDecoder())
        #expect(response.data == "raw-body")
    }
}

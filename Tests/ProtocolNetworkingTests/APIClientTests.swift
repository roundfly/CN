import Combine
import XCTest
@testable import ProtocolNetworking

final class APIClientTests: XCTestCase {

    func testPublishesCorrectData() {
        // given
        let promise = XCTestExpectation()
        let handler: (Data, URLResponse) -> Void = { (data, _) in
            let str = String(data: data, encoding: .utf8)!
            XCTAssertEqual(str, "Test")
            promise.fulfill()
        }
        // when
        sink(then: handler)
        // then
        wait(for: [promise], timeout: 0.1)
    }

    func testPublishesValidStatusCode() {
        // given
        let promise = XCTestExpectation()
        let handler: (Data, URLResponse) -> Void = { (_, res) in
            let httpResponse = res as? HTTPURLResponse
            XCTAssertNotNil(httpResponse)
            XCTAssertEqual(httpResponse?.statusCode, 200, "Invalid status code: \(httpResponse!.statusCode)")
            promise.fulfill()
        }
        // when
        sink(then: handler)
        // then
        wait(for: [promise], timeout: 0.1)
    }

    func testAPIClientDecodableRequest() {
        // given
        typealias UserRequest = ServiceRequest<User>
        let req = UserRequest(path: "/mock-user", method: .get)
        let apiClient = Netowrking(session: MockJSONSession())
        let promise = expectation(description: "decodable request expectation")
        // when
        _ = apiClient.fetch(using: req)
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .sink(receiveCompletion: { (completion) in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }},
                  receiveValue: { user in
                    XCTAssertEqual(user.name, "Test", "Invalid user decoded")
                    promise.fulfill()
            })
        // then
        wait(for: [promise], timeout: 0.1)
    }

    func testAPIClientEncodableRequest() {
        // given
        typealias StoryRequest = ServiceRequest<Story>
        let story = Story(id: .zero)
        let req = StoryRequest(path: "/mock-story", method: .post(.json))
        let apiClient = Netowrking(session: MockJSONSession())
        let promise = expectation(description: "encodable request expectation")
        // when
        _ = apiClient.send(story, using: req)
            .map(\.response)
            .sink(receiveCompletion: { _ in }, receiveValue: { res in
                XCTAssertEqual((res as? HTTPURLResponse)?.statusCode, 200, "Invalid status code")
                promise.fulfill()
            })
        // then
        wait(for: [promise], timeout: 0.1)
    }

    func testGETRequestBuildsCorrectly() throws {
        try testUrlRequest(with: .get)
    }

    func testPOSTRequestBuildsCorrectly() throws {
        try testUrlRequest(with: .post(.json))
    }

    func testPATCHRequestBuildsCorrectly() throws {
        try testUrlRequest(with: .update(.json))
    }

    func testPUTRequestBuildsCorrectly() throws {
        try testUrlRequest(with: .put(.json))
    }

    func testDELETERequestBuildsCorrectly() throws {
        try testUrlRequest(with: .delete)
    }

    func testAPIClientError() throws {
        // given
        struct NetworkingError: LocalizedError {
            var localizedDescription: String {
                "mock error"
            }
        }
        let url = try XCTUnwrap(URL(string: "/mock-url"))
        let req = ServiceRequest<User>(path: url.absoluteString)
        let apiClient = Netowrking(session: MockErrorSession())
        let promise = expectation(description: "API client error expectation")
        // when
        _ = apiClient.fetch(using: req)
            .mapError { _ in
                NetworkingError()
        }
        .sink(receiveCompletion: { completion in
            switch completion {
            case .failure:
                promise.fulfill()
            case .finished:
                XCTFail("Invalid state")
            }
        }, receiveValue: { _ in })
        // then
        wait(for: [promise], timeout: 0.1)
    }
}

private extension APIClientTests {

    // MARK: Mocks/Stubs

    struct User: Decodable {
        var name: String
    }

    struct Story: Encodable {
        var id: Int
    }

    enum StubReqLoader {
        static func loadRequest() -> URLRequest {
            URLRequest(url: URL(string: "https://urlsessiontests.com")!)
        }
    }

    struct MockSession: URLSessionProtocol {
        func publisher(for request: URLRequest) -> AnyPublisher<Output, URLError> {
            let data = "Test".data(using: .utf8)!
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)! as URLResponse
            return Result.Publisher((data: data, response: response)).eraseToAnyPublisher()
        }
    }

    struct MockJSONSession: URLSessionProtocol {
        func publisher(for request: URLRequest) -> AnyPublisher<Output, URLError> {
            let data = """
            {
                "name": "Test"
            }
            """.data(using: .utf8)!
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)! as URLResponse
            return Result.Publisher((data: data, response: response)).eraseToAnyPublisher()
        }
    }

    struct MockErrorSession: URLSessionProtocol {
        func publisher(for request: URLRequest) -> AnyPublisher<Output, URLError> {
            Result.Publisher(.failure(URLError(.badURL))).eraseToAnyPublisher()
        }
    }

    // MARK: Helpers

    @discardableResult
    func sink(then handler: @escaping (_ data: Data, _ response: URLResponse) -> Void) -> AnyCancellable {
        MockSession().publisher(for: StubReqLoader.loadRequest()).sink(receiveCompletion: { (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
        }, receiveValue: handler)
    }

    func testUrlRequest(with httpMethod: HTTPMethod) throws {
        // given
        typealias UserID = Int
        typealias StoryID = Int
        typealias UserIDRequest = ServiceRequest<UserID>
        typealias StoryIDRequest = ServiceRequest<StoryID>
        enum Header: String {
            case authorization = "Authorization"
        }

        let id = 1337
        let path: String
        let accessToken = "Bearer \(UUID().uuidString)"
        let headers = [Header.authorization.rawValue: accessToken]

        // when
        switch httpMethod {

        case .get, .delete:

            path = "/mock-user/\(id)"
            let req = UserIDRequest(path: path, method: httpMethod)
            let urlRequest = req.build(using: headers)
            // then
            XCTAssertEqual(urlRequest.url?.path, path, "Invalid url built")
            XCTAssertEqual(urlRequest.httpMethod, httpMethod.rawValue, "Invalid http method")
            XCTAssertEqual(urlRequest.allHTTPHeaderFields?[Header.authorization.rawValue], accessToken, "Header not set")

        case .post, .update, .put:

            let path = "/mock-story/\(id)"
            let story = Story(id: id)
            let payload = try JSONEncoder().encode(story)
            let req = StoryIDRequest(path: path, method: httpMethod)
            let urlRequest = req.build(from: story, using: headers)
            // then
            XCTAssertEqual(urlRequest.httpMethod, httpMethod.rawValue, "Invalid http method")
            XCTAssertEqual(urlRequest.url?.path, path, "Invalid url built")
            XCTAssertEqual(urlRequest.httpBody, payload, "Invalid request body set")
            XCTAssertEqual(urlRequest.allHTTPHeaderFields?[Header.authorization.rawValue], accessToken, "Header not set")
        }
    }
}

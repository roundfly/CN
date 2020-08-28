//
//  APIClientTests.swift
//  
//
//  Created by Nikola Stojanovic on 28/08/2020.
//

import Combine
import XCTest
@testable import StructNetworking

final class APIClientTests: XCTestCase {

    func testAPIClientDecodableRequest() throws {
        // given
        let json = """
        {
            "name": "Bob"
        }
        """
        let id = 1337
        let data = try XCTUnwrap(json.data(using: .utf8))
        APIClient.fetch = { (req) in
            let response = self.mockResponse(.success, from: req)
            return Result.Publisher((data: data, response: response)).eraseToAnyPublisher()
        }

        let promise = expectation(description: "user decodable request expectation")
        // when
        _ = APIClient.fetch(.user(id: id))
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .sink(receiveCompletion: { _ in }, receiveValue: { user in
                XCTAssertEqual("Bob", user.name, "Invalid user fetched")
                promise.fulfill()
        })
        // then
        wait(for: [promise], timeout: 0.1)
    }

    func testAPIClientEncodableRequest() {
        // given
        typealias StoryRequest = Request<ModelEncodable>
        let story = Story(id: .zero)
        let req: StoryRequest = .upload(of: story)
        let promise = expectation(description: "encodable request expectation")
        APIClient.send = { req in
            let response = self.mockResponse(.success, from: req)
            let buffer = Data(repeating: 0xff, count: 8)
            return Result.Publisher((data: buffer, response: response)).eraseToAnyPublisher()
        }
        // when
        _ = APIClient.send(req)
            .map(\.response)
            .sink(receiveCompletion: { _ in }) { (res) in
                XCTAssertEqual((res as? HTTPURLResponse)?.statusCode, 200, "Invalid status code")
                promise.fulfill()
        }
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
}

private extension APIClientTests {

    // MARK: Mocks/Stubs

    struct User: Decodable {
        var name: String
    }

    struct Story: Encodable {
        var id: Int
    }

    // MARK: Helpers

    enum ResponseType {
        case success
        case failure
    }

    func mockResponse(_ type: ResponseType, from req: Request<ModelDecodable>) -> URLResponse {
        guard let url = req.build().url,
            let res = HTTPURLResponse(url: url, statusCode: type == .success ? 200 : 404, httpVersion: "HTTP/1.1", headerFields: nil)
            else {
                preconditionFailure("Failed constructing response")
        }
        return res as URLResponse
    }

    func mockResponse(_ type: ResponseType, from req: Request<ModelEncodable>) -> URLResponse {
        guard let url = req.build().url,
            let res = HTTPURLResponse(url: url, statusCode: type == .success ? 200 : 404, httpVersion: "HTTP/1.1", headerFields: nil)
            else {
                preconditionFailure("Failed constructing response")
        }
        return res as URLResponse
    }

    func testUrlRequest(with httpMethod: HTTPMethod) throws {
        // given
        typealias UserID = ModelDecodable
        typealias StoryID = ModelEncodable
        typealias UserIDRequest = Request<UserID>
        typealias StoryIDRequest = Request<StoryID>
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
            let req = UserIDRequest(path: path, method: httpMethod, headers: headers)
            let urlRequest = req.build()
            // then
            XCTAssertEqual(urlRequest.url?.path, path, "Invalid url built")
            XCTAssertEqual(urlRequest.httpMethod, httpMethod.rawValue, "Invalid http method")
            XCTAssertEqual(urlRequest.allHTTPHeaderFields?[Header.authorization.rawValue], accessToken, "Header not set")

        case .post, .update, .put:

            let path = "/mock-story/\(id)"
            let story = Story(id: id)
            let payload = try JSONEncoder().encode(story)
            let req = StoryIDRequest(path: path, method: httpMethod, payload: story, headers: headers)
            let urlRequest = req.build()
            // then
            XCTAssertEqual(urlRequest.httpMethod, httpMethod.rawValue, "Invalid http method")
            XCTAssertEqual(urlRequest.url?.path, path, "Invalid url built")
            XCTAssertEqual(urlRequest.httpBody, payload, "Invalid request body set")
            XCTAssertEqual(urlRequest.allHTTPHeaderFields?[Header.authorization.rawValue], accessToken, "Header not set")
        }
    }
}

extension Request where Payload == ModelDecodable {

    static var allUsers: Self<ModelDecodable> {
        .init(path: "/users", host: "mock")
    }

    static func user(id: Int) -> Self<ModelDecodable> {
        .init(path: "/users/\(id)", host: "mock")
    }
}

extension Request where Payload == ModelEncodable {

    static func upload<T: Encodable>(of model: T) -> Self<ModelEncodable> {
        .init(path: "/mock", method: .post(.json), payload: model)
    }
}

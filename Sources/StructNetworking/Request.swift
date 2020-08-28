//
//  Request.swift
//  
//
//  Created by Nikola Stojanovic on 28/08/2020.
//

import Foundation

enum ModelType {
    enum Decodable {}
    enum Encodable {}
}

typealias ModelDecodable = ModelType.Decodable
typealias ModelEncodable = ModelType.Encodable

struct Request<Payload> {
    var path: String
    var host: String = "api.somehost.com/v1"
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem]?
    var headers: [String: String] = APIClient.defaultHeaders
    private var data: (() -> Data)?

    var components: URLComponents {
        var components = URLComponents()
        components.host = host
        components.scheme = "https"
        components.path = path
        components.queryItems = queryItems
        return components
    }

    init(path: String, host: String? = nil, headers: [String: String] = [:]) {
        self.path = path
        self.headers.merge(headers, uniquingKeysWith: { (current, _) in current })
        if let host = host {
            self.host = host
        }
    }

    func build() -> URLRequest {
        guard let url = components.url else {
            // TODO: log error and fail gracefully
            preconditionFailure()
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let contentType = method.contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = data?()
        // TODO: add UserAgent header
        headers.forEach { (key, value) in request.addValue(value, forHTTPHeaderField: key) }

        return request
    }
}

extension Request where Payload == ModelEncodable {

    init<T: Encodable>(path: String, method: HTTPMethod = .post(.json), payload: T, headers: [String: String] = [:]) {
        self.path = path
        self.method = method
        self.data = {
            guard let data = try? JSONEncoder().encode(payload) else {
                // TODO: log encoding error and fail gracefully
                preconditionFailure()
            }
            return data
        }
        self.headers.merge(headers, uniquingKeysWith: { (current, _) in current })
        assert(method)
    }

    private func assert(_ httpMethod: HTTPMethod) {
        switch httpMethod {
        case .post, .put, .update:
            break
        default:
            assertionFailure("Attempting to set http body of: \(httpMethod.rawValue) request")
            return
        }
    }
}

extension Request where Payload == ModelDecodable {

    init(path: String, method: HTTPMethod = .get, queryItems: [URLQueryItem]? = nil, headers: [String: String] = [:]) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers.merge(headers, uniquingKeysWith: { (current, _) in current })
    }
}

public enum HTTPMethod {
    case get
    case post(ContentType)
    case update(ContentType)
    case put(ContentType)
    case delete

    var rawValue: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .update: return "PATCH"
        case .put: return "PUT"
        case .delete: return "DELETE"
        }
    }

    var contentType: String? {
        switch self {
        case .post(let encoding):
            return encoding.rawValue
        case .update(let encoding):
            return encoding.rawValue
        case .put(let encoding):
            return encoding.rawValue
        default:
            return nil
        }
    }
}

public enum ContentType: String {
    case json = "application/json"
}


//
//  ServiceRequest.swift
//  
//
//  Created by Nikola Stojanovic on 28/08/2020.
//

import Foundation

public struct ServiceRequest<Payload> {
    public var path: String
    public var method: HTTPMethod
    public var queryItems: [URLQueryItem]?

    internal func urlBuilder() -> URLComponents {
        var components = URLComponents()
        components.host = "api.somehost.com/v1"
        components.scheme = "https"
        components.path = path
        components.queryItems = queryItems
        return components
    }

    public func build(using headers: [String: String] = [:]) -> URLRequest {
        guard let url = urlBuilder().url else {
            // TODO: log error and fail gracefully
            preconditionFailure()
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let contentType = method.contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        // TODO: add UserAgent header
        headers.forEach { (key, value) in request.addValue(value, forHTTPHeaderField: key) }
        return request
    }

}

extension ServiceRequest where Payload: Encodable {

    public init(path: String, method: HTTPMethod = .post(.json)) {
        self.path = path
        self.method = method
    }

    internal func build<T: Encodable>(from payload: T, using headers: [String: String] = [:]) -> URLRequest {
        guard let data = try? JSONEncoder().encode(payload) else {
            // TODO: log encoding error and fail gracefully
            preconditionFailure()
        }
        var request = build(using: headers)
        setup(body: data, of: &request)
        return request
    }

    private func setup(body: Data, of request: inout URLRequest) {
        switch method {
        case .post, .put, .update:
            request.httpBody = body
        default:
            break
        }
    }
}

public extension ServiceRequest where Payload: Decodable {

    init(path: String, method: HTTPMethod = .get, queryItems: [URLQueryItem]? = nil) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
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

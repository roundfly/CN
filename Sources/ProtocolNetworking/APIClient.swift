//
//  Netowrking.swift
//  
//
//  Created by Nikola Stojanovic on 28/08/2020.
//

import Combine
import Foundation

public protocol URLSessionProtocol {
    typealias Output = URLSession.DataTaskPublisher.Output
    func publisher(for request: URLRequest) -> AnyPublisher<Output, URLError>
}

extension URLSession: URLSessionProtocol {
    public func publisher(for request: URLRequest) -> AnyPublisher<Output, URLError> {
        dataTaskPublisher(for: request).eraseToAnyPublisher()
    }
}

public protocol APIRemoteInteraction {
    typealias ServiceResponse = URLSession.Output
    func fetch<T: Decodable>(using request: ServiceRequest<T>) -> AnyPublisher<ServiceResponse, URLError>
    func send<T: Encodable>(_ payload: T, using request: ServiceRequest<T>) -> AnyPublisher<ServiceResponse, URLError>
}

public final class Netowrking: APIRemoteInteraction {

    private let session: URLSessionProtocol

    private var defaultHeaders: [String: String] {
        // TODO: Add default headers..
        [:]
    }

    public init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    public func fetch<T: Decodable>(using request: ServiceRequest<T>) -> AnyPublisher<ServiceResponse, URLError> {
        session.publisher(for: request.build(using: defaultHeaders))
    }

    public func send<T: Encodable>(_ payload: T, using request: ServiceRequest<T>) -> AnyPublisher<ServiceResponse, URLError> {
        session.publisher(for: request.build(from: payload, using: defaultHeaders))
    }
}

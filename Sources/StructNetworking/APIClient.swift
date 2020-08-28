//
//  APIClient.swift
//  
//
//  Created by Nikola Stojanovic on 28/08/2020.
//

import Combine
import Foundation


struct RemoteStoreInteractor {
    typealias Output = URLSession.DataTaskPublisher.Output
    var defaultHeaders: [String: String] = [:]
    var fetch: (_ req: Request<ModelDecodable>) -> AnyPublisher<Output, URLError> = Self.defaultFetch
    var send:  (_ req: Request<ModelEncodable>) -> AnyPublisher<Output, URLError> = Self.defaultSend
}

extension RemoteStoreInteractor {

    static var defaultFetch: (_ req: Request<ModelDecodable>) -> AnyPublisher<Output, URLError> { {
        URLSession.shared.dataTaskPublisher(for: $0.build()).eraseToAnyPublisher()
        }
    }

    static var defaultSend: (_ req: Request<ModelEncodable>) -> AnyPublisher<Output, URLError> { {
        URLSession.shared.dataTaskPublisher(for: $0.build()).eraseToAnyPublisher()
        }
    }
}

#if DEBUG

var APIClient = RemoteStoreInteractor()

#else

let APIClient = RemoteStoreInteractor()

#endif

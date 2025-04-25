//
//  ResponseValidator.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//


import Foundation

public protocol ResponseValidator {
    func validate(_ data: Data, response: URLResponse) throws
}

public struct DefaultResponseValidator: ResponseValidator {
    public func validate(_ data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw NetworkError.badRequest(try? JSONDecoder().decode(APIError.self, from: data))
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
}

public struct APIError: Error, Decodable, Sendable {
    let code: String
    let message: String
}

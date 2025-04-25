//
//  NetworkError.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//


import Foundation

/// Represents all possible network-related errors
public enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case badRequest(APIError?)
    case serverError(Int)
    case networkFailure(Error)
    case unexpectedStatusCode(Int)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .badRequest(let apiError):
            return apiError?.message ?? "Bad request"
        case .serverError(let code):
            return "Server error occurred (\(code))"
        case .networkFailure(let error):
            return "Network failure: \(error.localizedDescription)"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code: \(code)"
        case .cancelled:
            return "Request was cancelled"
        }
    }
    
    var isRetriable: Bool {
        switch self {
        case .serverError, .networkFailure:
            return true
        default:
            return false
        }
    }
}

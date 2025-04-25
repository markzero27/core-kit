//
//  RequestInterceptor.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//


import Foundation

/// Protocol defining the requirements for intercepting and modifying requests
public protocol RequestInterceptor {
    /// Adapts the request before it is sent
    /// - Parameter request: The original request
    /// - Returns: The modified request
    func adapt(_ request: URLRequest) async throws -> URLRequest
    
    /// Determines whether a failed request should be retried
    /// - Parameters:
    ///   - request: The failed request
    ///   - response: The response received, if any
    ///   - error: The error that occurred
    /// - Returns: Whether the request should be retried
    func retry(_ request: URLRequest, for response: URLResponse?, error: Error?) async throws -> Bool
}

/// Default implementation of RequestInterceptor
public final class DefaultRequestInterceptor: RequestInterceptor {
    private let retryLimit: Int
    private let retryDelay: TimeInterval
    private let appSession: NetworkSession
    private var currentRetry = 0
    
    public init(
        retryLimit: Int = 3,
        retryDelay: TimeInterval = 1.0,
        appSession: NetworkSession = .shared
    ) {
        self.retryLimit = retryLimit
        self.retryDelay = retryDelay
        self.appSession = appSession
    }
    
    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var adaptedRequest = request
        
        // Add common headers
        adaptedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization if authenticated
        if let accessToken = appSession.accessToken {
            adaptedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        return adaptedRequest
    }
    
    public func retry(_ request: URLRequest, for response: URLResponse?, error: Error?) async throws -> Bool {
        guard currentRetry < retryLimit else { return false }
        
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 401: // Unauthorized
                do {
                    guard let refreshToken = appSession.refreshToken else {
                        appSession.clearTokens()
                        return false
                    }
                    
                    // Try to refresh the token
                    let newToken = try await appSession.refreshAccessToken()
                    appSession.setTokens(accessToken: newToken, refreshToken: refreshToken)
                    return true
                    
                } catch {
                    appSession.clearTokens()
                    return false
                }
                
            case 408, // Request Timeout
                 500, // Internal Server Error
                 502, // Bad Gateway
                 503, // Service Unavailable
                 504: // Gateway Timeout
                currentRetry += 1
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return true
                
            default:
                return false
            }
        }
        
        if let error = error as NSError?, error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorTimedOut,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost:
                currentRetry += 1
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

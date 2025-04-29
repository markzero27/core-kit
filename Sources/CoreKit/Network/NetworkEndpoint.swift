//
//  NetworkEndpoint.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//

import Foundation

/// Protocol defining the requirements for an API endpoint
public protocol NetworkEndpoint {
    /// The base URL of the endpoint
    var baseURL: URL? { get }
    
    /// The path component of the endpoint
    var path: String { get }
    
    /// The HTTP method to be used
    var method: HTTPMethod { get }
    
    /// Optional HTTP headers
    var headers: [String: String]? { get }
    
    /// Optional query parameters
    var queryItems: [URLQueryItem]? { get }
    
    /// Optional request body
    var body: [String: Any]? { get }
    
    /// Optional timeout interval
    var timeoutInterval: TimeInterval { get }
    
    /// Cache policy for this specific endpoint
    var cachePolicy: URLRequest.CachePolicy { get }
    
    /// Retry limit for this specific endpoint
    var retryLimit: Int { get }
    
    /// Enables logging for this specific endpoint
    var isLoggingEnabled: Bool { get }
}

public extension NetworkEndpoint {
    
    var headers: [String: String]? { nil }
    
    var queryItems: [URLQueryItem]? { nil }
    
    var body: [String: Any]? { nil }
    
    var timeoutInterval: TimeInterval { 60.0 }
    
    var cachePolicy: URLRequest.CachePolicy { .reloadIgnoringLocalAndRemoteCacheData }
    
    var retryLimit: Int { 3 }
    
    var isLoggingEnabled: Bool { true }
}

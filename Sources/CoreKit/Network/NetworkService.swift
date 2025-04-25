//
//  NetworkServiceProtocol.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//

import Foundation
import os.log

public protocol NetworkServiceProtocol {
    associatedtype Endpoint: NetworkEndpoint
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws
}

public final class NetworkService<Endpoint: NetworkEndpoint>: NetworkServiceProtocol {
   
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let interceptor: RequestInterceptor
    private let validator: ResponseValidator
    private let logger: Logger
    private let cache: URLCache
    
    init(
        configuration: NetworkConfiguration = .default,
        session: URLSession = .shared,
        interceptor: RequestInterceptor = DefaultRequestInterceptor(),
        validator: ResponseValidator = DefaultResponseValidator(),
        cache: URLCache = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.interceptor = interceptor
        self.validator = validator
        self.cache = cache
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NetworkService",
                             category: String(describing: NetworkService.self))
    }
    
    public func request(_ endpoint: Endpoint) async throws {
        let _: EmptyResponse = try await request(endpoint)
    }
    
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        do {
            let request = try buildURLRequest(for: endpoint)
            logRequest(request)
            
            let adaptedRequest = try await adaptRequest(request)
            let (data, response) = try await performRequest(adaptedRequest)
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("""
                    📥 Response Data:
                    ================
                    \(self.formatJSON(responseString))
                    ================
                    """)
            }
            
            try validator.validate(data, response: response)
            logResponse(response, for: adaptedRequest)
            
            return try decodeResponse(data)
            
        } catch {
            logError("Network Request Failed", error)
            throw mapError(error)
        }
    }
    
    // MARK: - Private Request Building Methods
    
    private func buildURLRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let baseURL = endpoint.baseURL else {
            logger.error("⛔️ No base URL provided in endpoint")
            throw NetworkError.invalidURL
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                       resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = endpoint.queryItems
        
        guard let url = urlComponents?.url else {
            logger.error("⛔️ Failed to build URL for endpoint: \(endpoint.path)")
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(
            url: url,
            cachePolicy: endpoint.cachePolicy,
            timeoutInterval: endpoint.timeoutInterval
        )
        
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.headers
        
        if let body = endpoint.body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                    logger.debug("""
                        📤 Request Body:
                        ================
                        \(self.formatJSON(bodyString))
                        ================
                        """)
                }
            } catch {
                logger.error("⛔️ Failed to serialize request body: \(error.localizedDescription)")
                throw NetworkError.encodingError(error)
            }
        }
        
        return request
    }
    
    private func adaptRequest(_ request: URLRequest) async throws -> URLRequest {
        try await interceptor.adapt(request)
    }
    
    // MARK: - Private Request Execution Methods
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var currentRequest = request
        var lastError: Error?
        
        for attempt in 0...configuration.retryLimit {
            do {
                if attempt > 0 {
                    try await handleRetryAttempt(attempt)
                }
                
                return try await session.data(for: currentRequest)
                
            } catch {
                lastError = error
                logger.error("❌ Attempt \(attempt + 1) failed: \(error.localizedDescription)")
                if try await shouldRetry(currentRequest, error: error) {
                    currentRequest = try await interceptor.adapt(request)
                    continue
                }
                break
            }
        }
        
        throw lastError ?? NetworkError.networkFailure(NSError(domain: "", code: -1))
    }
    
    private func handleRetryAttempt(_ attempt: Int) async throws {
        logger.debug("🔄 Retrying request (Attempt \(attempt)/\(self.configuration.retryLimit))")
        try await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
    }
    
    private func shouldRetry(_ request: URLRequest, error: Error) async throws -> Bool {
        try await interceptor.retry(request, for: nil, error: error)
    }
    
    // MARK: - Private Response Handling Methods
    
    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logError("Decoding Failed for type: \(T.self)", error)
            throw NetworkError.decodingError(error)
        }
    }
    
    // MARK: - Private Logging Methods
    
    private func logRequest(_ request: URLRequest) {
        logger.debug("""
            📡 REQUEST
            =========
            \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")
            
            Headers:
            \(self.formatHeaders(request.allHTTPHeaderFields ?? [:]))
            =========
            """)
    }
    
    private func logResponse(_ response: URLResponse, for request: URLRequest) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        let statusEmoji = httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 ? "✅" : "⚠️"
        
        logger.debug("""
            📡 RESPONSE \(statusEmoji)
            =========
            [\(httpResponse.statusCode)] \(request.url?.absoluteString ?? "")
            
            Headers:
            \(self.formatHeaders(httpResponse.allHeaderFields as? [String: Any] ?? [:]))
            =========
            """)
    }
    
    private func logError(_ context: String, _ error: Error) {
        logger.error("""
            ❌ \(context)
            =========
            Error: \(error.localizedDescription)
            
            Details:
            \(String(describing: error))
            =========
            """)
    }
    
    // MARK: - Private Formatting Helpers
    
    private func formatHeaders(_ headers: [String: Any]) -> String {
        headers.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
    }
    
    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
    
    // MARK: - Private Error Handling
    
    private func mapError(_ error: Error) -> NetworkError {
        let mappedError: NetworkError
        switch error {
        case is DecodingError:
            mappedError = .decodingError(error)
        case is EncodingError:
            mappedError = .encodingError(error)
        case let networkError as NetworkError:
            mappedError = networkError
        case URLError.cancelled:
            mappedError = .cancelled
        default:
            mappedError = .networkFailure(error)
        }
        return mappedError
    }
}

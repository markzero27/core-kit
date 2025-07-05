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
    
    public init(
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
            
            if endpoint.isLoggingEnabled {
                logRequest(request, endpoint: endpoint)
            }
            
            let adaptedRequest = try await adaptRequest(request)
            let (data, response) = try await performRequest(adaptedRequest)
            
            // Log response data for debugging
            if endpoint.isLoggingEnabled, let responseString = String(data: data, encoding: .utf8) {
                logger.debug("""
                    📥 Response Data:
                    ================
                    \(self.formatJSON(responseString))
                    ================
                    """)
            }
            
            try validator.validate(data, response: response)
            
            if endpoint.isLoggingEnabled {
                logResponse(response, for: adaptedRequest)
            }
            
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
        
        if let multipartData = getMultipartFormData(from: endpoint) {
            request.httpBody = multipartData
            
            // Automatically set Content-Type header if not already set
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                // Try to extract boundary from the multipart data or generate one
                let boundary = extractBoundaryFromMultipartData(multipartData) ?? UUID().uuidString
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            }
            
            if endpoint.isLoggingEnabled {
                logger.debug("""
                    📤 Request Body (Multipart):
                    ================
                    Multipart form data (\(multipartData.count) bytes)
                    Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "Not set")
                    ================
                    """)
            }
        } else if let body = endpoint.body {
            // Check if we need form encoding based on Content-Type
            if let contentType = request.value(forHTTPHeaderField: "Content-Type"),
               contentType.contains("application/x-www-form-urlencoded") {
                // Form encode the data
                var components = URLComponents()
                components.queryItems = body.map { key, value in
                    URLQueryItem(name: "\(key)", value: "\(value)")
                }
                
                if let formData = components.percentEncodedQuery {
                    request.httpBody = formData.data(using: .utf8)
                } else {
                    logger.error("⛔️ Failed to create form encoded data")
                    throw NetworkError.encodingError(NSError(domain: "FormEncodingError", code: 0))
                }
            } else {
                // JSON encode the data (existing behavior)
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                        logger.debug("""
                            📤 Request Body (JSON):
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
        }
        
        return request
    }

    // Helper method to extract boundary from multipart data
    private func extractBoundaryFromMultipartData(_ data: Data) -> String? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        // Updated regex to match any alphanumeric boundary, not just hex
        let pattern = "--([A-Za-z0-9-]+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        
        if let match = regex?.firstMatch(in: string, options: [], range: range),
           let boundaryRange = Range(match.range(at: 1), in: string) {
            return String(string[boundaryRange])
        }
        
        return nil
    }
    
    private func getMultipartFormData(from endpoint: Endpoint) -> Data? {
        if let endpointWithMultipart = endpoint as? any MultipartFormDataCapable {
            return endpointWithMultipart.multipartFormData()
        }
        
        return nil
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
    
    private func logRequest(_ request: URLRequest, endpoint: Endpoint) {
        let bodyInfo: String
        if let body = request.httpBody {
            if getMultipartFormData(from: endpoint) != nil {
                let multipartInfo = analyzeMultipartData(body)
                bodyInfo = "Multipart form data (\(body.count) bytes) - \(multipartInfo)"
            } else if let contentType = request.value(forHTTPHeaderField: "Content-Type"),
                      contentType.contains("application/x-www-form-urlencoded") {
                bodyInfo = "Form encoded data (\(body.count) bytes)"
            } else {
                bodyInfo = "JSON body (\(body.count) bytes)"
            }
        } else {
            bodyInfo = "No body"
        }
        
        logger.debug("""
            📡 REQUEST
            =========
            \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")
            Body: \(bodyInfo)
            
            Headers:
            \(self.formatHeaders(request.allHTTPHeaderFields ?? [:]))
            =========
            """)
    }
    
    private func analyzeMultipartData(_ data: Data) -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            return "Binary data"
        }
        
        let boundaryPattern = "--([A-Za-z0-9-]+)"
        let fieldPattern = "Content-Disposition: form-data; name=\"([^\"]+)\""
        
        let boundaryRegex = try? NSRegularExpression(pattern: boundaryPattern, options: [])
        let fieldRegex = try? NSRegularExpression(pattern: fieldPattern, options: [])
        
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        
        var boundary = "Unknown"
        if let match = boundaryRegex?.firstMatch(in: string, options: [], range: range),
           let boundaryRange = Range(match.range(at: 1), in: string) {
            boundary = String(string[boundaryRange])
        }
        
        let fieldMatches = fieldRegex?.matches(in: string, options: [], range: range) ?? []
        let fieldNames = fieldMatches.compactMap { match -> String? in
            guard let fieldRange = Range(match.range(at: 1), in: string) else { return nil }
            return String(string[fieldRange])
        }
        
        return "Boundary: \(boundary), Fields: [\(fieldNames.joined(separator: ", "))]"
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

public struct EmptyResponse: Decodable {}
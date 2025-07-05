//
//  NetworkEndpoint.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//

import Foundation
import UIKit

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

/// Represents a file to be uploaded
public struct MultipartFile {
    public let data: Data
    public let filename: String
    public let mimeType: String
    
    public init(data: Data, filename: String, mimeType: String) {
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
    
    /// Convenience initializer for UIImage with automatic JPEG conversion
    public init(image: UIImage, filename: String, compressionQuality: CGFloat = 0.8) {
        self.data = image.jpegData(compressionQuality: compressionQuality) ?? Data()
        self.filename = filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg") ? filename : "\(filename).jpg"
        self.mimeType = "image/jpeg"
    }
    
    /// Convenience initializer for UIImage with PNG conversion
    public init(imagePNG: UIImage, filename: String) {
        self.data = imagePNG.pngData() ?? Data()
        self.filename = filename.hasSuffix(".png") ? filename : "\(filename).png"
        self.mimeType = "image/png"
    }
}

/// Protocol for defining multipart form data content
public protocol MultipartFormDataProtocol {
    /// Files to be uploaded as part of the multipart data
    var files: [String: MultipartFile] { get }
    /// Form fields to be included as part of the multipart data
    var formFields: [String: String] { get }
}

/// Protocol for endpoints that support multipart form data
public protocol MultipartFormDataCapable {
    /// Returns multipart form data if the endpoint supports it
    func multipartFormData() -> Data?
}

public extension NetworkEndpoint {
    
    var headers: [String: String]? { nil }
    
    var queryItems: [URLQueryItem]? { nil }
    
    var body: [String: Any]? { nil }
    
    var timeoutInterval: TimeInterval { 60.0 }
    
    var cachePolicy: URLRequest.CachePolicy { .reloadIgnoringLocalAndRemoteCacheData }
    
    var retryLimit: Int { 3 }
    
    var isLoggingEnabled: Bool { true }
    
    /// Creates multipart form data with boundary
    /// - Parameter data: The multipart data protocol containing files and form fields
    /// - Returns: A tuple containing the multipart body data and boundary string
    func createMultipartFormData(with data: MultipartFormDataProtocol) -> (Data, String) {
        let boundary = UUID().uuidString
        let body = createMultipartBody(with: data, boundary: boundary)
        return (body, boundary)
    }
    
    /// Creates the multipart body data
    /// - Parameters:
    ///   - data: The multipart data protocol containing files and form fields
    ///   - boundary: The boundary string for multipart separation
    /// - Returns: The formatted multipart body data
    func createMultipartBody(with data: MultipartFormDataProtocol, boundary: String) -> Data {
        var body = Data()
        
        // Add form fields
        for (key, value) in data.formFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // Add files
        for (key, file) in data.files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(file.filename)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
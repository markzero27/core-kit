//
//  AppSession.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//


import Foundation

public protocol NetworkSessionProtocol {
    var isAuthenticated: Bool { get }
    var accessToken: String? { get }
    var refreshToken: String? { get }
    
    func refreshAccessToken() async throws -> String
    func setTokens(accessToken: String, refreshToken: String)
    func clearTokens()
}

/// Manages authentication state and tokens
public class NetworkSession: NetworkSessionProtocol {
    /// Shared instance for authentication management
    nonisolated(unsafe) public static let shared = NetworkSession()
    
    /// Current access token for API requests
    public private(set) var accessToken: String?
    
    /// Refresh token for obtaining new access tokens
    public private(set) var refreshToken: String?
    
    /// Returns true if user is authenticated (has valid access token)
    public var isAuthenticated: Bool {
        accessToken != nil
    }
    
    /// Allow subclassing
    public init() {
        loadTokens()
    }
    
    /// Sets new authentication tokens
    /// - Parameters:
    ///   - accessToken: The new access token
    ///   - refreshToken: The new refresh token
    open func setTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        // Save tokens to secure storage
        saveTokens()
    }
    
    /// Clears all authentication tokens
    open func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        // Remove tokens from secure storage
        removeTokens()
    }
    
    /// Attempts to refresh the access token using the refresh token
    /// - Returns: A new access token
    /// - Throws: NetworkError if refresh fails
    open func refreshAccessToken() async throws -> String {
        guard refreshToken != nil else {
            throw NetworkError.unauthorized
        }
        
        // TODO: Implement token refresh logic
        // Make API call to refresh token
        throw NetworkError.unauthorized
    }
    
    // MARK: - Private Methods
    
    open func saveTokens() {
        // Save to UserDefaults for now, should use Keychain in production
        let defaults = UserDefaults.standard
        defaults.set(accessToken, forKey: "accessToken")
        defaults.set(refreshToken, forKey: "refreshToken")
    }
    
    open func loadTokens() {
        // Load from UserDefaults for now, should use Keychain in production
        let defaults = UserDefaults.standard
        accessToken = defaults.string(forKey: "accessToken")
        refreshToken = defaults.string(forKey: "refreshToken")
    }
    
    open func removeTokens() {
        // Remove from UserDefaults for now, should use Keychain in production
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "accessToken")
        defaults.removeObject(forKey: "refreshToken")
    }
}

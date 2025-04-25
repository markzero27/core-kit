//
//  HTTPMethod.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//


import Foundation

/// HTTP methods supported by the API
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

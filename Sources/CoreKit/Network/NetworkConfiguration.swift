//
//  NetworkConfiguration.swift
//  FitSenpai
//
//  Created by Mark Daquis on 4/2/25.
//


import Foundation

/// Configuration for network service
public struct NetworkConfiguration {
    let timeoutInterval: TimeInterval
    let retryLimit: Int
    let retryDelay: TimeInterval
    
    nonisolated(unsafe) public static let `default` = NetworkConfiguration(
        timeoutInterval: 30,
        retryLimit: 3,
        retryDelay: 1.0
    )
}

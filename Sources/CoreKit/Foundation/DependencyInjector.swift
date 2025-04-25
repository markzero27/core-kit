//
//  DependencyInjector.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//

import Foundation

public class DependencyInjector {
    nonisolated(unsafe) private static var dependencies: [AnyHashable: Any] = [:]

    public static func register<T>(_ dependency: T, key: String? = nil) {
        let lookupKey: AnyHashable
        if let key = key {
            lookupKey = key
        } else {
            lookupKey = ObjectIdentifier(T.self)
        }
        dependencies[lookupKey] = dependency
    }

    public static func resolve<T, Key: Hashable>(key: Key? = nil) -> T {
        let lookupKey: AnyHashable
        if let key = key {
            lookupKey = key
        } else {
            lookupKey = ObjectIdentifier(T.self)
        }

        guard let dependency = dependencies[lookupKey] as? T else {
            fatalError("No dependency found for \(lookupKey)")
        }
        return dependency
    }
}

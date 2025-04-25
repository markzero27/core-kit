//
//  Inject.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//

import Foundation

@propertyWrapper
public struct Inject<T> {
    private let key: DIKey?

    public init(key: DIKey? = nil) {
        self.key = key
    }

    public var wrappedValue: T {
        DependencyInjector.resolve(key: key)
    }
}

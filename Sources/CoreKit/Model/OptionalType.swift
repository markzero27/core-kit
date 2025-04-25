//
//  OptionalType.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//

import Foundation

public protocol OptionalType {
    var isNil: Bool { get }
}

extension Optional: OptionalType {
    public var isNil: Bool { self == nil }
}

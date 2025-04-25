//
//  Preferences.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//

import Foundation
import Combine

// Convert Preferences to a protocol
public protocol Preferences: ObservableObject {
    var preferencesChangedSubject: PassthroughSubject<AnyKeyPath, Never> { get }
    var userDefaults: UserDefaults { get }

    init(userDefaults: UserDefaults)
}

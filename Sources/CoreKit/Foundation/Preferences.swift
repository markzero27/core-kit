//
//  Preferences.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//

import Foundation
import Combine

public class Preferences {
    
    @MainActor public static let standard = Preferences(userDefaults: .standard)
    private(set) var userDefaults: UserDefaults
    
    /// Sends through the changed key path whenever a change occurs.
    var preferencesChangedSubject = PassthroughSubject<AnyKeyPath, Never>()
    
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}

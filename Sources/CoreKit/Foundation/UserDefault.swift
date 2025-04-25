//
//  UserDefault.swift
//  CoreKit
//
//  Created by Mark Daquis on 4/25/25.
//

import Foundation

@propertyWrapper
public struct UserDefault<Value> {
    let key: String
    let defaultValue: Value

    public var wrappedValue: Value {
        get { fatalError("Wrapped value should not be used.") }
        set { fatalError("Wrapped value should not be used.") }
    }
    
    public init(wrappedValue: Value, _ key: String) {
        self.defaultValue = wrappedValue
        self.key = key
    }
    
    public static subscript(
        _enclosingInstance instance: Preferences,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<Preferences, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Preferences, Self>
    ) -> Value {
        get {
            let container = instance.userDefaults
            let key = instance[keyPath: storageKeyPath].key
            let defaultValue = instance[keyPath: storageKeyPath].defaultValue
        
            
            if defaultValue is Date? {
                if let timestamp = container.object(forKey: key) as? TimeInterval {
                    return Date(timeIntervalSince1970: timestamp) as! Value
                }
                return defaultValue
            }
            
            let value = container.object(forKey: key) as? Value ?? defaultValue
            return value
        }
        set {
            let container = instance.userDefaults
            let key = instance[keyPath: storageKeyPath].key
            
            if let optional = newValue as? OptionalType, optional.isNil {
                container.removeObject(forKey: key)
            } else if let date = newValue as? Date {
                let timestamp = date.timeIntervalSince1970
                container.set(timestamp, forKey: key)
            } else {
                container.set(newValue, forKey: key)
            }
            
            container.synchronize()
            instance.preferencesChangedSubject.send(wrappedKeyPath)
        }
    }
}

import Core
import class Foundation.UserDefaults

/// A user defaults key, the key name will be the name of the key used in
/// the user defaults dictionary
public protocol UserDefaultsKey: Hashable where Conversion.Value == Value {
 associatedtype Value
 associatedtype Conversion: ValueConversion
 static var defaultValue: Value { get }
 /// This can be set to indicate whether a value should be removed when modified
 /// Such as instances where a value is the default or nil
 static func shouldRemove(_ newValue: Value) -> Bool
 /// This can be set to indicate whether a value should be added when modified
 /// Such as instances where values are equal
 static func shouldOverwrite(_ oldValue: Value, _ newValue: Value) -> Bool
}

public extension UserDefaultsKey {
 @_disfavoredOverload
 static func shouldRemove(_ newValue: Value) -> Bool { false }
 @_disfavoredOverload
 static func shouldOverwrite(_: Value, _: Value) -> Bool { true }
}

// MARK: - Overloads
public extension UserDefaultsKey where Value: Equatable {
 static func shouldRemove(_ newValue: Value) -> Bool
  where Value: ExpressibleByNilLiteral {
  nil ~= newValue || String(describing: newValue).readable == "nil"
 }

 @_disfavoredOverload
 static func shouldRemove(_ newValue: Value) -> Bool {
  newValue == defaultValue
 }

 @_disfavoredOverload
 static func shouldOverwrite(_ oldValue: Value, _ newValue: Value) -> Bool {
  newValue != defaultValue && newValue != oldValue
 }
}

public extension UserDefaultsKey where Value: ExpressibleByNilLiteral {
 @_disfavoredOverload
 static var defaultValue: Value { nil }
}

public extension UserDefaultsKey where Value: Infallible {
 @_disfavoredOverload
 static var defaultValue: Value { .defaultValue }
}

extension UserDefaultsKey {
 @usableFromInline
 static var name: String { String(describing: Self.self) }
}

public protocol StandardUserDefaultsValue {}
extension Bool: StandardUserDefaultsValue {}
extension String: StandardUserDefaultsValue {}
import struct Foundation.UUID
extension UUID: StandardUserDefaultsValue {}
extension Optional: StandardUserDefaultsValue
 where Wrapped: StandardUserDefaultsValue {}

public protocol StandardUserDefaultsKey: UserDefaultsKey
 where Value: StandardUserDefaultsValue, Conversion == PassthroughConversion<Value> {}

import protocol Combine.TopLevelEncoder
import protocol Core.AutoCodable

// MARK: - Defaults
/// A user defaults that allows typed conversion through the protocol
/// ``ValueConversion`` using value specific subscripts
open class CustomUserDefaults: UserDefaults {
 public static let shared = CustomUserDefaults()
 var cache: [String: Any] = .empty
 /// An unchecked key subcript that can store values without a conversion method
 /// Important: Key values must conform to `StandardUserDefaultsValue` to
 /// indicate that they are supported by the standard `UserDefaults`
 open subscript<Key: StandardUserDefaultsKey>(standard key: Key.Type) -> Key.Value {
  get {
   let key = Key.name
   let contains = self.dictionaryRepresentation().keys.contains(key)
   if contains {
    if let value = self.cache[key] {
     assert(value is Key.Value, "value for \(key) must be \(Key.Value.self)")
     return value as! Key.Value
    } else if let value = self.value(forKey: key) {
     assert(value is Key.Value, "value for \(key) must be \(Key.Value.self)")
     self.cache[key] = value
     return value as! Key.Value
    }
   }
   let value = Key.defaultValue
   self.cache[key] = value
   return value
  }
  set {
   guard !Key.shouldRemove(newValue) else {
    let key = Key.name
    self.cache.removeValue(forKey: key)
    self.removeObject(forKey: key)
    return
   }
   let oldValue = self[standard: Key.self]
   if Key.shouldOverwrite(oldValue, newValue) {
    let key = Key.name
    self.cache[key] = newValue
    // before setting, do some final checking if there are file size limitations, etc.
    // ...
    self.set(newValue, forKey: key)
   }
  }
 }

 open subscript<Key: UserDefaultsKey>(custom key: Key.Type) -> Key.Value {
  get {
   let converter = Key.Conversion.self
   let key = Key.name
   let contains = self.dictionaryRepresentation().keys.contains(key)
   if contains {
    if let value = self.cache[key] {
     assert(value is Key.Value, "value for \(key) must be \(Key.Value.self)")
     return value as! Key.Conversion.Value
    } else if let data = self.value(forKey: key) {
     assert(
      data is Key.Conversion.Data,
      "value for \(key) must be \(Key.Conversion.Data.self)"
     )
     let value = converter.decode(data: data as! Key.Conversion.Data)
     self.cache[key] = value
     return value
    }
   }
   let value = Key.defaultValue
   self.cache[key] = value
   return value
  }
  set {
   guard !Key.shouldRemove(newValue) else {
    let key = Key.name
    self.cache.removeValue(forKey: key)
    self.removeObject(forKey: key)
    return
   }
   let oldValue = self[custom: Key.self]
   if Key.shouldOverwrite(oldValue, newValue) {
    let key = Key.name
    self.cache[key] = newValue
    // before setting, do some final checking if there are file size limitations, etc.
    // ...
    self.set(Key.Conversion.encode(value: newValue), forKey: key)
   }
  }
 }
}

/// A defaults that can be used to access an observable user defaults instance
@propertyWrapper
public struct DefaultsProperty<Defaults, Key, Value>
 where Defaults: CustomUserDefaults, Key: UserDefaultsKey {
 let key: Key
 let keyPath: WritableKeyPath<Key.Value, Value>
 unowned let defaults: Defaults

 var keyValue: Key.Value {
  get { defaults[custom: Key.self] }
  nonmutating set { defaults[custom: Key.self] = newValue }
 }

 public var wrappedValue: Value {
  get { keyValue[keyPath: keyPath] }
  nonmutating set {
   keyValue[keyPath: keyPath] = newValue
  }
 }

 public var projectedValue: Binding<Value> {
  Binding(
   get: { self.wrappedValue },
   set: { self.wrappedValue = $0 }
  )
 }

 public mutating func update() {}

 public init(_ key: Key)
  where Defaults == CustomUserDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = .shared
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == CustomUserDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = .shared
 }
}

/// An unchecked storage for standard values that can be stored in the
/// standard `UserDefaults`
@propertyWrapper
public struct StandardDefaultsProperty<Defaults, Key, Value>
 where Defaults: CustomUserDefaults, Key: StandardUserDefaultsKey {
 let key: Key
 let keyPath: WritableKeyPath<Key.Value, Value>
 unowned let defaults: Defaults

 var keyValue: Key.Value {
  get { defaults[standard: Key.self] }
  nonmutating set { defaults[standard: Key.self] = newValue }
 }

 public var wrappedValue: Value {
  get { keyValue[keyPath: keyPath] }
  nonmutating set {
   keyValue[keyPath: keyPath] = newValue
  }
 }

 public var projectedValue: Binding<Value> {
  Binding(
   get: { self.wrappedValue },
   set: { self.wrappedValue = $0 }
  )
 }

 public mutating func update() {}

 public init(_ key: Key)
  where Defaults == CustomUserDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = .shared
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == CustomUserDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = .shared
 }
}

typealias UserDefault<Key, Value> =
 DefaultsProperty<CustomUserDefaults, Key, Value>
  where Key: UserDefaultsKey

typealias StandardDefault<Key, Value> =
 StandardDefaultsProperty<CustomUserDefaults, Key, Value>
  where Key: StandardUserDefaultsKey

#if canImport(SwiftUI)
import SwiftUI
/// A base class for creating observable objects for storing defaults where
/// values are convertible from their user default counterparts through the
/// ``ValueConversion`` protocol so no arbitrary values can be stored
/// There should also be a limit to the amount of data an object or key can store
/// if this occurs the stored value can be immediately updates using a cache
open class ViewDefaults: CustomUserDefaults & ViewObserver {
 public static let view = ViewDefaults()
 /// An unchecked key subcript that can store values without a conversion method
 /// Important: Key values must conform to `StandardUserDefaultsValue` to
 /// indicate that they are supported by the standard `UserDefaults`
 override open subscript<Key: StandardUserDefaultsKey>(
  standard key: Key.Type
 ) -> Key.Value {
  get {
   let key = Key.name
   let contains = self.dictionaryRepresentation().keys.contains(key)
   if contains {
    if let value = self.cache[key] {
     assert(value is Key.Value, "value for \(key) must be \(Key.Value.self)")
     return value as! Key.Value
    } else if let value = self.value(forKey: key) {
     assert(value is Key.Value, "value for \(key) must be \(Key.Value.self)")
     self.cache[key] = value
     return value as! Key.Value
    }
   }
   let value = Key.defaultValue
   self.cache[key] = value
   return value
  }
  set {
   guard !Key.shouldRemove(newValue) else {
    let key = Key.name
    DispatchQueue.main.async { self.objectWillChange.send() }
    self.cache.removeValue(forKey: key)
    self.removeObject(forKey: key)
    return
   }
   let oldValue = self[standard: Key.self]
   if Key.shouldOverwrite(oldValue, newValue) {
    let key = Key.name
    DispatchQueue.main.async { self.objectWillChange.send() }
    self.cache[key] = newValue
    // before setting, do some final checking if there are file size limitations, etc.
    // ...
    self.set(newValue, forKey: key)
   }
  }
 }

 override open subscript<Key: UserDefaultsKey>(custom key: Key.Type) -> Key.Value {
  get {
   let converter = Key.Conversion.self
   let key = Key.name
   let contains = self.dictionaryRepresentation().keys.contains(key)
   if contains {
    if let value = self.cache[key] {
     assert(value is Key.Value, "value for \(key) must be \(Key.Value.self)")
     return value as! Key.Conversion.Value
    } else if let data = self.value(forKey: key) {
     assert(
      data is Key.Conversion.Data,
      "value for \(key) must be \(Key.Conversion.Data.self)"
     )
     let value = converter.decode(data: data as! Key.Conversion.Data)
     self.cache[key] = value
     return value
    }
   }
   let value = Key.defaultValue
   self.cache[key] = value
   return value
  }
  set {
   guard !Key.shouldRemove(newValue) else {
    let key = Key.name
    DispatchQueue.main.async { self.objectWillChange.send() }
    self.cache.removeValue(forKey: key)
    self.removeObject(forKey: key)
    return
   }
   let oldValue = self[custom: Key.self]
   if Key.shouldOverwrite(oldValue, newValue) {
    let key = Key.name
    DispatchQueue.main.async { self.objectWillChange.send() }
    self.cache[key] = newValue
    // before setting, do some final checking if there are file size limitations, etc.
    // ...
    self.set(Key.Conversion.encode(value: newValue), forKey: key)
   }
  }
 }
}

/// A defaults that can be used to access an observable user defaults instance
@propertyWrapper
public struct ViewDefaultsProperty<Defaults, Key, Value>: DynamicProperty
 where Defaults: ViewDefaults, Key: UserDefaultsKey {
 let key: Key
 let keyPath: WritableKeyPath<Key.Value, Value>
 @ObservedObject var defaults: Defaults

 var keyValue: Key.Value {
  get { defaults[custom: Key.self] }
  nonmutating set { defaults[custom: Key.self] = newValue }
 }

 public var wrappedValue: Value {
  get { keyValue[keyPath: keyPath] }
  nonmutating set {
   keyValue[keyPath: keyPath] = newValue
  }
 }

 public var projectedValue: Binding<Value> {
  Binding(
   get: { self.wrappedValue },
   set: { self.wrappedValue = $0 }
  )
 }

 public func update() {
  let key = Key.name
  if defaults.cache.keys.contains(key),
     !defaults.dictionaryRepresentation().keys.contains(key) {
   defaults.cache.removeValue(forKey: key)
  }
 }

 public init(_ key: Key) where Defaults == ViewDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = .view
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == ViewDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = .view
 }
}

/// An unchecked storage for standard values that can be stored in the
/// standard `UserDefaults`
@propertyWrapper
public struct StandardViewDefaultsProperty
<Defaults, Key, Value>: DynamicProperty
 where Defaults: ViewDefaults, Key: StandardUserDefaultsKey {
 let key: Key
 let keyPath: WritableKeyPath<Key.Value, Value>
 @ObservedObject var defaults: Defaults

 var keyValue: Key.Value {
  get { defaults[standard: Key.self] }
  nonmutating set { defaults[standard: Key.self] = newValue }
 }

 public var wrappedValue: Value {
  get { keyValue[keyPath: keyPath] }
  nonmutating set {
   keyValue[keyPath: keyPath] = newValue
  }
 }

 public var projectedValue: Binding<Value> {
  Binding(
   get: { self.wrappedValue },
   set: { self.wrappedValue = $0 }
  )
 }

 public func update() {
  let key = Key.name
  if defaults.cache.keys.contains(key),
     !defaults.dictionaryRepresentation().keys.contains(key) {
   defaults.cache.removeValue(forKey: key)
  }
 }

 public init(_ key: Key) where Defaults == ViewDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = .view
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == ViewDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = .view
 }
}

public extension View {
 typealias Default<Key, Value> =
  ViewDefaultsProperty<ViewDefaults, Key, Value>
   where Key: UserDefaultsKey

 typealias Standard<Key, Value> =
  StandardViewDefaultsProperty<ViewDefaults, Key, Value>
   where Key: StandardUserDefaultsKey
}

@available(macOS 11.0, *)
public extension App {
 typealias Default<Key, Value> =
  ViewDefaultsProperty<ViewDefaults, Key, Value>
   where Key: UserDefaultsKey

 typealias Standard<Key, Value> =
  StandardViewDefaultsProperty<ViewDefaults, Key, Value>
   where Key: StandardUserDefaultsKey
}
#endif
#if canImport(Command)
import Command
public extension CommandProtocol {
 typealias Default<Key, Value> =
  DefaultsProperty<CustomUserDefaults, Key, Value>
   where Key: UserDefaultsKey

 typealias Standard<Key, Value> =
  StandardDefaultsProperty<CustomUserDefaults, Key, Value>
   where Key: StandardUserDefaultsKey
}
#endif

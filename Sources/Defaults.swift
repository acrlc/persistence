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
 static var name: String { get }
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

public extension UserDefaultsKey {
 @_disfavoredOverload
 @inlinable static var name: String { String(describing: Self.self) }
}

public protocol StandardUserDefaultsValue {}
extension Bool: StandardUserDefaultsValue {}
extension Int: StandardUserDefaultsValue {}
extension Int8: StandardUserDefaultsValue {}
extension Int16: StandardUserDefaultsValue {}
extension Int32: StandardUserDefaultsValue {}
extension UInt: StandardUserDefaultsValue {}
extension UInt8: StandardUserDefaultsValue {}
extension UInt16: StandardUserDefaultsValue {}
extension UInt32: StandardUserDefaultsValue {}
extension String: StandardUserDefaultsValue {}
extension Double: StandardUserDefaultsValue {}
extension [String: Any]: StandardUserDefaultsValue {}

import struct Foundation.UUID
extension UUID: StandardUserDefaultsValue {}
extension Optional: StandardUserDefaultsValue
 where Wrapped: StandardUserDefaultsValue {}

public protocol StandardUserDefaultsKey: UserDefaultsKey
 where Value: StandardUserDefaultsValue, Conversion == PassthroughConversion<Value> {}

import protocol Combine.TopLevelEncoder
import protocol Core.AutoCodable

// MARK: - Defaults -
public extension UserDefaults {
 func isMissing<A: UserDefaultsKey>(key _: A) -> Bool {
  object(forKey: A.name) == nil
 }

 func isMissing<A: StandardUserDefaultsKey>(key _: A) -> Bool {
  object(forKey: A.name) == nil
 }

 func contains<A: UserDefaultsKey>(key _: A) -> Bool {
  object(forKey: A.name) != nil
 }

 func contains<A: StandardUserDefaultsKey>(key _: A) -> Bool {
  object(forKey: A.name) != nil
 }
}

// MARK: - Custom
/// A user defaults that allows typed conversion through the protocol
/// ``ValueConversion`` using value specific subscripts
open class CustomUserDefaults: UserDefaults {
 // static var cache: [String: Any] = .empty

 public func reset() {
  for key in self.dictionaryRepresentation().keys {
   self.removeObject(forKey: key)
  }
 }

 /// An unchecked key subcript that can store values without a conversion method
 /// Important: Key values must conform to `StandardUserDefaultsValue` to
 /// indicate that they are supported by the standard `UserDefaults`
 open subscript<Key: StandardUserDefaultsKey>(standard key: Key.Type) -> Key.Value {
  get { self.value(forKey: Key.name) as? Key.Value ?? Key.defaultValue }
  set {
   guard !Key.shouldRemove(newValue) else {
    self.removeObject(forKey: Key.name)
    return
   }
   if Key.shouldOverwrite(self[standard: Key.self], newValue) {
    self.set(newValue, forKey: Key.name)
   }
  }
 }

 open subscript<Key: UserDefaultsKey>(custom key: Key.Type) -> Key.Value {
  get {
   let key = Key.name
   if let data = self.value(forKey: key) {
    return Key.Conversion.self.decode(data: data as! Key.Conversion.Data)
   }
   return Key.defaultValue
  }
  set {
   guard !Key.shouldRemove(newValue) else {
    self.removeObject(forKey: Key.name)
    return
   }
   if Key.shouldOverwrite(self[custom: Key.self], newValue) {
    self.set(Key.Conversion.encode(value: newValue), forKey: Key.name)
   }
  }
 }
}

extension UserDefaults {
 public static let custom = CustomUserDefaults()
}

public extension CustomUserDefaults {
 subscript<A: UserDefaultsKey>(_: A) -> A.Value {
  get { self[custom: A.self] }
  set { self[custom: A.self] = newValue }
 }

 subscript<A: StandardUserDefaultsKey>(_: A) -> A.Value {
  get { self[standard: A.self] }
  set { self[standard: A.self] = newValue }
 }

 func removeValue<A: UserDefaultsKey>(forKey: A) {
  removeObject(forKey: A.name)
 }

 func removeValue<A: StandardUserDefaultsKey>(forKey: A) {
  removeObject(forKey: A.name)
 }

// open subscript<Key: CustomStringConvertible, Value: StandardUserDefaultsValue>(
//  standard key: Key, defaultValue: Value
// ) -> Key.Value {
//  get { self.value(forKey: Key.name) as? Key.Value ?? Key.defaultValue }
//  set {
//   guard !Key.shouldRemove(newValue) else {
//    self.removeObject(forKey: Key.name)
//    return
//   }
//   if Key.shouldOverwrite(self[standard: Key.self], newValue) {
//    self.set(newValue, forKey: Key.name)
//   }
//  }
// }
// // TODO: Base subscripting on customizable strings, so overite and removal rules
// // can inherit from this
// open subscript<Key: CustomStringConvertible, Value, Conversion: ValueConversion>(
//  custom key: Key,
//  defaultValue: Value,
//  conversion: Conversion,
//  shouldRemove: (Value) -> Bool = { _ in true },
//  shouldOverwrite: (Value, Value) -> Bool = { _, _ in true }
// ) -> Value where Conversion.Value == Value {
//  get {
//   let key = key.description
//   if let data = self.value(forKey: key) {
//    return Conversion.decode(data: data as! Conversion.Data)
//   }
//   return defaultValue
//  }
//  set {
//   guard !shouldRemove(newValue) else {
//    self.removeObject(forKey: key.description)
//    return
//   }
//   if shouldOverwrite(
//    self[custom: key, defaultValue, conversion, shouldRemove, shouldOverwrite],
//    newValue
//   ) {
//    self.set(Conversion.encode(value: newValue), forKey: key.description)
//   }
//  }
// }
}

/// A defaults that can be used to access an observable user defaults instance
@propertyWrapper
public struct DefaultsProperty<Defaults, Key, Value>
 where Defaults: CustomUserDefaults, Key: UserDefaultsKey {
 let key: Key
 let keyPath: WritableKeyPath<Key.Value, Value>
 let defaults: Defaults

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

 // public mutating func update() {}

 public init(_ key: Key)
  where Defaults == CustomUserDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = .custom
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == CustomUserDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = .custom
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

 // public mutating func update() {}

 public init(_ key: Key)
  where Defaults == CustomUserDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = .custom
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == CustomUserDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = .custom
 }
}

public typealias UserDefault<Key, Value> =
 DefaultsProperty<CustomUserDefaults, Key, Value>
  where Key: UserDefaultsKey

public typealias StandardDefault<Key, Value> =
 StandardDefaultsProperty<CustomUserDefaults, Key, Value>
  where Key: StandardUserDefaultsKey

#if canImport(SwiftUI)
import SwiftUI
/// A base class for creating observable objects for storing defaults where
/// values are convertible from their user default counterparts through the
/// ``ValueConversion`` protocol so no arbitrary values can be stored
open class ViewDefaults: CustomUserDefaults & ViewObserver {
 /// An unchecked key subcript that can store values without a conversion method
 /// Important: Key values must conform to `StandardUserDefaultsValue` to
 /// indicate that they are supported by the standard `UserDefaults`
 override open subscript<Key: StandardUserDefaultsKey>(
  standard key: Key.Type
 ) -> Key.Value {
  get { self.value(forKey: Key.name) as? Key.Value ?? Key.defaultValue }
  set {
   guard !Key.shouldRemove(newValue) else {
    self.objectWillChange.send()
    self.removeObject(forKey: Key.name)
    return
   }
   if Key.shouldOverwrite(self[standard: Key.self], newValue) {
    self.objectWillChange.send()
    self.set(newValue, forKey: Key.name)
   }
  }
 }

 override open subscript<Key: UserDefaultsKey>(custom key: Key.Type) -> Key.Value {
  get {
   let key = Key.name
   if let data = self.value(forKey: key) {
    return Key.Conversion.self.decode(data: data as! Key.Conversion.Data)
   }
   return Key.defaultValue
  }
  set {
   guard !Key.shouldRemove(newValue) else {
    self.objectWillChange.send()
    self.removeObject(forKey: Key.name)
    return
   }
   if Key.shouldOverwrite(self[custom: Key.self], newValue) {
    self.objectWillChange.send()
    self.set(Key.Conversion.encode(value: newValue), forKey: Key.name)
   }
  }
 }
}

extension UserDefaults {
 public static let view = ViewDefaults()
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

// public func update() {
//  let key = Key.name
//  if Defaults.cache.keys.contains(key),
//     !defaults.dictionaryRepresentation().keys.contains(key) {
//   Defaults.cache.removeValue(forKey: key)
//  }
// }

 public init(_ key: Key) where Defaults == ViewDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = ViewDefaults()
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == ViewDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = ViewDefaults()
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

// public func update() {
//  let key = Key.name
//  if Defaults.cache.keys.contains(key),
//     !defaults.dictionaryRepresentation().keys.contains(key) {
//   Defaults.cache.removeValue(forKey: key)
//  }
// }

 public init(_ key: Key) where Defaults == ViewDefaults, Value == Key.Value {
  self.key = key
  self.keyPath = \Key.Value.self
  self.defaults = ViewDefaults()
 }

 public init(
  _ key: Key, _ keyPath: WritableKeyPath<Key.Value, Value>
 ) where Defaults == ViewDefaults {
  self.key = key
  self.keyPath = keyPath
  self.defaults = ViewDefaults()
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

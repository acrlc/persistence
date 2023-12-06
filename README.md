This package aims to provide keys and convertible values to the `UserDefaults` class and provide integration with existing frameworks
### Keys
```swift
struct FirstLaunchKey: UserDefaultsKey {
 static let defaultValue: Bool = false
 // static func shouldRemove(_ value: Bool) -> Bool
 // static func shouldOverwrite(_ oldValue: Bool, _ newValue: Bool) -> Bool
}
// Define a static key used for the property wrapper
extension UserDefaultsKey where Self == FirstLaunchKey {
 static var firstLaunch: Self { Self() } 
}
// `@Standard` property wrapper can be used to update views 
@Standard(.firstLaunch) var firstLaunch
// or `@StandardDefault` to update the value globally
@StandardDefault(.firstLaunch) var firstLaunch
```
### Value Conversion
Standard values use the `PassthroughConversion` method

Custom values must use a `ValueConversion` method
```swift
struct IntBoolConversion: ValueConversion {
  /// The data converted before reading
 static func decode(data: Int) -> Bool { data > 0 ? true : false }
  /// The value converted before storing
 static func encode(value: Bool) -> Int { value ? 1 : 0 }
}
// A key using the `IntBoolConversion` method
struct TestKey: UserDefaultsKey {
 typealias Conversion = IntBoolConversion
 static let defaultValue: Bool = false
}
extension UserDefaultsKey where Self == TestKey {
 static var testValue: Self { Self() } 
}
// Now this value can automatically be converted
// with the `@Default` property on views
@Default(.testValue) var value
// or globally with `@UserDefault`
@UserDefault(.testValue) var value
```
AutoCodable values are supported with `CodableDefaultsKey`
```swift
// Any value conforming to `AutoCodable`
struct Defaults: JSONCodable {}
// The value's key that can be used
// within a local context with `@Default` or globally with `@UserDefault`
struct DefaultsKey: CodableDefaultsKey {
 static let defaultValue = Defaults()
}
```
### Performance
When testing, the differences appear to be neglible with this wrapper adding ~0.1ms or ~0.0001s compared to not using a wrapper when setting a bool value and modifying it.
public protocol ValueConversion {
 associatedtype Value
 associatedtype Data
 /// The data converted before reading
 static func decode(data: Data) -> Value
 /// The value converted before storing
 static func encode(value: Value) -> Data
}

extension Never: ValueConversion {
 public static func decode(data: Never) -> Never {}
 public static func encode(value: Never) -> Never {}
}

/// A struct for values that convert back and forth from the same type
public struct PassthroughConversion<Value>: ValueConversion {
 public static func decode(data: Value) -> Value { data }
 public static func encode(value: Value) -> Value { value }
}

import Core
import protocol Combine.TopLevelEncoder
import Extensions

public struct CodeConversion<Value: AutoCodable>: ValueConversion {
 public typealias Data = Value.AutoEncoder.Output
 public static func decode(data: Data) -> Value {
  do { return try Value.decoder.decode(Value.self, from: data) }
  catch { fatalError(error.message) }
 }

 public static func encode(value: Value) -> Data {
  do { return try Value.encoder.encode(value) }
  catch { fatalError(error.message) }
 }
}

public extension UserDefaultsKey where Value: AutoCodable {
 typealias Conversion = CodeConversion<Value>
}

public protocol CodableDefaultsKey: UserDefaultsKey
 where Value: AutoCodable, Conversion == CodeConversion<Value> {}

// MARK: Serializable
public struct SerialConversion<Value: AutoSerializable>: ValueConversion {
 public typealias Data = [String: Any]
 public static func decode(data: Data) -> Value {
  do {
   return try Value.decoder.decode(Value.self, from: Value.deserialize(data))
  }
  catch { fatalError(error.message) }
 }
 
 public static func encode(value: Value) -> Data {
  do { return try Value.serialize(Value.encoder.encode(value)) }
  catch { fatalError(error.message) }
 }
}

public extension UserDefaultsKey where Value: AutoSerializable {
 typealias Conversion = SerialConversion<Value>
}

public protocol SerialDefaultsKey: UserDefaultsKey
where Value: AutoSerializable, Conversion == SerialConversion<Value> {}



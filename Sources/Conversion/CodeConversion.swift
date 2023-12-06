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

protocol CodableDefaultsKey: UserDefaultsKey
 where Value: AutoCodable, Conversion == CodeConversion<Value> {}

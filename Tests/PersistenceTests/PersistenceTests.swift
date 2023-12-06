import XCTest
@testable import Persistence

final class PersistenceTests: XCTestCase {
 let defaults = UserDefaults.standard
 func reset() {
  for key in ["ToggleTestKey", "OptionalTestKey"] {
   defaults.removeObject(forKey: key)
  }
 }

 override func tearDown() { reset() }
 deinit { reset() }

 var measureOptions: XCTMeasureOptions {
  let options = XCTMeasureOptions.default
  options.iterationCount = 999
  return options
 }

 /// Check and then measure performance for `UserDefaults`
 func testUserDefaultsWrite() {
  /// measure toggling values
  measure(options: measureOptions) {
   defaults.setValue(false, forKey: "ToggleTestKey")
   defaults.setValue(true, forKey: "ToggleTestKey")
  }
 }

 func testUserDefaultsRead() {
  /// measure reading toggled value
  measure { _ = defaults.bool(forKey: "ToggleTestKey") }
 }

 // MARK: - Custom Implementation
 let customDefaults = CustomUserDefaults.shared

 /// Ensures that the protocol overrides work
 func testOverloads() {
  // keys are removed or typically ignored when set to their default value
  // ensure value is stored
  customDefaults[standard: ToggleTestKey.self] = true
  XCTAssert(customDefaults.bool(forKey: ToggleTestKey.name) == true)

  // set to default value `false`
  customDefaults[standard: ToggleTestKey.self] = false
  XCTAssert(customDefaults.value(forKey: ToggleTestKey.name) == nil)

  // ensure the subscript reads as `false`
  XCTAssert(customDefaults[standard: ToggleTestKey.self] == false)

  // test an optional value
  customDefaults[standard: OptionalTestKey.self] = "Hello!"
  XCTAssert(customDefaults.string(forKey: OptionalTestKey.name) == "Hello!")

  customDefaults[standard: OptionalTestKey.self] = nil
  // make sure the key was removed
  XCTAssert(
   !customDefaults.dictionaryRepresentation().keys.contains(OptionalTestKey.name)
  )

  XCTAssert(customDefaults[standard: OptionalTestKey.self] == nil)
 }

 /// Check that subscripts properly work with `CustomUserDefaults`
 func testCustomWrite() {
  /// measure toggling values
  measure(options: measureOptions) {
   customDefaults[standard: ToggleTestKey.self] = false
   customDefaults[standard: ToggleTestKey.self] = true
  }
 }

 func testCustomRead() {
  /// measure reading toggled values
  measure { _ = customDefaults[standard: ToggleTestKey.self] }
 }

 /// Test property wrappers when used within views or globally
 func test() throws {
  @StandardDefault(.toggleTest) var boolValue
  XCTAssert(boolValue == false)

  boolValue.toggle()
  XCTAssert(boolValue == true)

  let boolValueFromStorage =
   try XCTUnwrap(customDefaults.value(forKey: ToggleTestKey.name) as? Bool)
  XCTAssert(boolValueFromStorage == true)

  boolValue.toggle()
  XCTAssert(boolValue == false)
  XCTAssert(customDefaults.value(forKey: ToggleTestKey.name) == nil)

  @StandardDefault(.optionalTest) var optionalValue
  XCTAssert(optionalValue == nil)

  optionalValue = "Hello!"
  XCTAssert(optionalValue == "Hello!")

  let optionalValueFromStorage =
   try XCTUnwrap(customDefaults.value(forKey: OptionalTestKey.name) as? String)
  XCTAssert(optionalValueFromStorage == "Hello!")

  optionalValue = nil
  XCTAssert(
   !customDefaults.dictionaryRepresentation().keys.contains(OptionalTestKey.name)
  )
  XCTAssert(optionalValue == nil)
 }
}

struct ToggleTestKey: StandardUserDefaultsKey {
 static let defaultValue = false
}

extension UserDefaultsKey where Self == ToggleTestKey {
 static var toggleTest: Self { Self() }
}

struct OptionalTestKey: StandardUserDefaultsKey {
 static var defaultValue: String?
}

extension UserDefaultsKey where Self == OptionalTestKey {
 static var optionalTest: Self { Self() }
}

import SwiftUI
import Core
// FIXME: plistcodable not encoding
enum Tag: String, JSONCodable, CaseIterable, ExpressibleByNilLiteral {
 case none, clear, green, orange, blue, red
 init(nilLiteral: ()) { self = .none }

 var color: Color? {
  switch self {
  case .clear: return .clear
  case .green: return .green
  case .orange: return .orange
  case .blue: return .blue
  case .red: return .red
  default: return nil
  }
 }

 var next: AllCases.Element? {
  guard
   let index = Self.allCases.firstIndex(of: self)
  else { return nil }
  let nextIndex = Self.allCases.index(index, offsetBy: 1)
  if nextIndex < Self.allCases.endIndex {
   return Self.allCases[nextIndex]
  } else {
   return nil
  }
 }
}

struct TagKey: CodableDefaultsKey {
 static let defaultValue: Tag = .none
}

extension UserDefaultsKey where Self == TagKey {
 static var tag: Self { Self() }
}

struct LabelKey: StandardUserDefaultsKey {
 // FIXME: this value cannot be nil because swiftui doesn't allow nil by default
 // come up with a protocol solution for nil values
 // although, empty values should be deleted using the defaults wrapper
 static let defaultValue: String = .empty
}

extension UserDefaultsKey where Self == LabelKey {
 static var label: Self { Self() }
}

@available(macOS 14.0, *)
struct PersistentUI: App {
 var body: some Scene {
  WindowGroup {
   ContentView().frame(width: 311)
  }
  .windowResizability(.contentSize)
 }

 struct ContentView: View {
  @Default(.tag) var tag
  @Standard(.label) var label

  var body: some View {
   VStack {
    HStack(alignment: .firstTextBaseline) {
     Text("Tag")
     Button(tag.rawValue) {
      if let next = tag.next { tag = next }
      else { tag = nil }
     }
     .buttonStyle(.borderedProminent)
     .tint(tag.color)
     .frame(width: 64)
     .animation(.interactiveSpring, value: tag)
     TextField("Label", text: $label)
     Button("Clear") { clear() }.disabled(isDisabled).padding(.leading)
     Spacer()
    }
    VStack(alignment: .leading, spacing: 8.5) {
     HStack {
      Text("Key for ") +
       Text("Tag").foregroundStyle(tag.color ?? .primary) +
       Text(" is \(nilDescription(for: "TagKey"))")
      Spacer()
     }
     HStack {
      Text("Key for Label is \(nilDescription(for: "LabelKey"))")
      Spacer()
     }
     HStack {
      Text("Note: Must copy, cut, or paste a value for label").font(.footnote)
      Spacer()
     }
    }
    .padding(.top, 11.5)
   }
   .padding()
  }

  let defaults = ViewDefaults.view

  func nilDescription(for key: String) -> String {
   defaults.dictionaryRepresentation().keys.contains(key) == nil ? "nil" : "not nil"
  }

  var isDisabled: Bool {
   ["TagKey", "LabelKey"].map {
    defaults.dictionaryRepresentation().keys.contains($0)
   }
   .allSatisfy { $0 == false }
  }

  func clear() {
   defaults.objectWillChange.send()
   for key in ["TagKey", "LabelKey"] {
    defaults.removeObject(forKey: key)
   }
  }
 }
}

@available(macOS 14.0, *)
final class PersistenceUITests: XCTestCase {
 func test() { PersistentUI.main() }
}

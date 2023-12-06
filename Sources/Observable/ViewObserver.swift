#if canImport(SwiftUI)
import protocol Combine.ObservableObject
import class Combine.ObservableObjectPublisher
public protocol ViewObserver: ObservableObject
where Self.ObjectWillChangePublisher == ObservableObjectPublisher {}
#endif

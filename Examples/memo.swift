#!/usr/bin/env swift-shell
import Command // @git/acrlc/command
import Persistence // ..

/// A persistent echo command
@main struct MemoCommand: Command {
 @StandardDefault(.memo) var memo
 @Flag var reset: Bool
 @Input var newValue: String?
 
 var output: String {
  memo ??
   "nothing to remember. set as first input, or use flag -r or -reset to reset."
 }

 func main() {
  if reset {
   if memo == nil { exit(2, "nothing to reset") }
   else { memo = nil; exit(0) }
  }
  if let newValue { memo = newValue }
  print(output)
 }
}

struct MemoKey: StandardUserDefaultsKey /* UserDefaultsKey */ {
 static var defaultValue: String?
}

extension UserDefaultsKey where Self == MemoKey {
 static var memo: Self { Self() }
}

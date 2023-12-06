// swift-tools-version:5.5
import PackageDescription

let package = Package(
 name: "Persistence",
 platforms: [.macOS(.v10_15), .iOS(.v15)],
 products: [.library(name: "Persistence", targets: ["Persistence"])],
 dependencies: [
  .package(url: "https://github.com/acrlc/core.git", from: "0.1.0")
 ],
 targets: [
  .target(
   name: "Persistence", dependencies: [
    .product(name: "Core", package: "core"),
    .product(name: "Extensions", package: "Core")
   ],
   path: "Sources"
  ),
  .testTarget(
   name: "PersistenceTests",
   dependencies: [
    "Persistence",
    .product(name: "Core", package: "core")
   ]
  )
 ]
)

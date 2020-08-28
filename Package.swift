// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreNetworking",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: Module.protocolNetworking, targets: [Module.protocolNetworking]),
        .library(name: Module.structNetworking, targets: [Module.structNetworking])
    ],
    
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: Module.protocolNetworking,
            dependencies: []),
        .testTarget(
            name: Module.Test.protocolNetworking,
            dependencies: ["ProtocolNetworking"]),
        .target(
            name: Module.structNetworking,
            dependencies: []),
        .testTarget(
            name: Module.Test.structNetworking,
            dependencies: ["StructNetworking"]),
    ]
)

enum Module {
    static let protocolNetworking = "ProtocolNetworking"
    static let structNetworking = "StructNetworking"
    enum Test {
        static let protocolNetworking = "ProtocolNetworkingTests"
        static let structNetworking = "StructNetworkingTests"
    }
}

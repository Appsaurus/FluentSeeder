// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FluentSeeder",
    platforms: [
        .macOS(.v10_12)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FluentSeeder",
            targets: ["FluentSeeder"]),
    ],
    dependencies: [
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent.git", from:"3.0.0"),
		.package(url: "https://github.com/vapor/fluent-sqlite.git", from:"3.0.0"),
		.package(url: "https://github.com/Appsaurus/RandomFactory", from: "1.0.0"),
		.package(url: "https://github.com/Appsaurus/FluentExtensions", from: "0.0.1"),
		.package(url: "https://github.com/Appsaurus/FluentTestUtils", from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FluentSeeder",
            dependencies: ["Vapor", "Fluent", "RandomFactory", "FluentExtensions"]),
        .testTarget(
            name: "FluentSeederTests",
            dependencies: ["FluentSeeder", "FluentTestUtils", "FluentSQLite"]),
    ]
)

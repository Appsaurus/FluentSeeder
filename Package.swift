// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FluentSeeder",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FluentSeeder",
            targets: ["FluentSeeder"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/vapor/fluent.git", .upToNextMajor(from:"4.0.0")),
		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", .upToNextMajor(from:"4.0.0")),
		.package(url: "https://github.com/Appsaurus/RandomFactory.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/Appsaurus/FluentExtensions.git", .branch("vapor-4"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "FluentSeeder",
            dependencies: [.product(name: "Vapor", package: "vapor"),
                           .product(name: "Fluent", package: "fluent"),
                           .product(name: "RandomFactory", package: "RandomFactory"),
                           .product(name: "FluentExtensions", package: "FluentExtensions")]),
        .testTarget(
            name: "FluentSeederTests",
            dependencies: [.target(name: "FluentSeeder"),
                           .product(name: "Fluent", package: "fluent"),
                           .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")]),
    ]
)

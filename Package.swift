// swift-tools-version:5.4
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
        .library(
            name: "FluentSeeder",
            targets: ["FluentSeeder"]),
        .library(
            name: "FluentTestModelsSeeder",
            targets: ["FluentTestModelsSeeder"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/vapor/fluent.git", .upToNextMajor(from:"4.0.0")),
		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", .upToNextMajor(from:"4.0.0")),
		.package(url: "https://github.com/Appsaurus/RandomFactory.git", .branch("swift-5.4")),
        .package(url: "https://github.com/Appsaurus/FluentExtensions.git", .upToNextMajor(from:"1.0.0"))
    ],
    targets: [
        .target(
            name: "FluentSeeder",
            dependencies: [.product(name: "Vapor", package: "vapor"),
                           .product(name: "Fluent", package: "fluent"),
                           .product(name: "RandomFactory", package: "RandomFactory"),
                           .product(name: "FluentExtensions", package: "FluentExtensions")]),
        .target(
            name: "FluentTestModelsSeeder",
            dependencies: [.target(name: "FluentSeeder"),
                           .product(name: "FluentTestModels", package: "FluentExtensions")]),
        .testTarget(
            name: "FluentSeederTests",
            dependencies: [.target(name: "FluentTestModelsSeeder"),
                           .product(name: "Fluent", package: "fluent"),
                           .product(name: "FluentTestModels", package: "FluentExtensions"),
                           .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")]),
    ]
)

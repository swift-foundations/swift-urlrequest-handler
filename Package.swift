// swift-tools-version: 6.3.3

import Foundation
import PackageDescription

extension String {
    static let urlRequestHandler: Self = "URLRequestHandler"
}

extension Target.Dependency {
    static var urlRequestHandler: Self { .target(name: .urlRequestHandler) }
}

extension Target.Dependency {
    static var dependencies: Self { .product(name: "Dependencies", package: "swift-dependencies") }
    static var dependenciesTestSupport: Self { .product(name: "Dependencies Test Support", package: "swift-dependencies") }
    static var loggerDependencies: Self { .product(name: "Logger Dependencies", package: "swift-logger-dependencies") }
    static var logging: Self { .product(name: "Logging", package: "swift-log") }
}

let package = Package(
    name: "swift-urlrequest-handler",
    platforms: [
      .iOS(.v26),
      .macOS(.v26),
      .tvOS(.v26),
      .watchOS(.v26)
    ],
    products: [
        .library(name: .urlRequestHandler, targets: [.urlRequestHandler])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-dependencies.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-logger-dependencies.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: .urlRequestHandler,
            dependencies: [
                .dependencies,
                .loggerDependencies,
                .logging
            ]
        ),
        .testTarget(
            name: .urlRequestHandler.tests,
            dependencies: [
                .urlRequestHandler,
                .dependenciesTestSupport
            ]
        )
    ]
)

extension String { var tests: Self { self + " Tests" } }

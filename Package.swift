// swift-tools-version: 6.3.1

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
    static var issueReporting: Self { .product(name: "IssueReporting", package: "xctest-dynamic-overlay") }
    static var loggingExtras: Self { .product(name: "LoggingExtras", package: "swift-logging-extras") }
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
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
        .package(url: "https://github.com/swift-foundations/swift-logging-extras.git", branch: "main")
    ],
    targets: [
        .target(
            name: .urlRequestHandler,
            dependencies: [
                .dependencies,
                .issueReporting,
                .loggingExtras
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
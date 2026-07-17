# swift-urlrequest-handler

[![CI](https://github.com/coenttb/swift-urlrequest-handler/workflows/CI/badge.svg)](https://github.com/coenttb/swift-urlrequest-handler/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

A Swift package for URLRequest handling with structured error handling.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
  - [Basic Request Handling](#basic-request-handling)
  - [Envelope Response Pattern](#envelope-response-pattern)
  - [Custom JSON Decoder](#custom-json-decoder)
  - [Void Requests](#void-requests)
  - [Error Handling](#error-handling)
  - [Testing with Mocks](#testing-with-mocks)
  - [Custom URLSession](#custom-urlsession)
- [API Reference](#api-reference)
  - [URLRequest.Handler](#urlrequesthandler)
  - [RequestError](#requesterror)
  - [Envelope](#envelope)
- [Testing](#testing)
- [Related Packages](#related-packages)
- [Requirements](#requirements)
- [License](#license)
- [Contributing](#contributing)

## Overview

A type-safe URLRequest handling system with automatic envelope/direct response decoding, structured error handling, and dependency injection via swift-dependencies.

## Features

- Type-safe request handling with automatic response decoding
- Envelope pattern support (automatically handles both envelope-wrapped and direct JSON responses)
- Structured error handling with detailed error types and context
- Privacy-conscious logging (automatic sanitization of sensitive headers)
- Dependency injection via swift-dependencies
- Configurable JSON decoding with sensible defaults
- Debug mode for testing with enhanced logging
- Testable URLSession abstraction

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-urlrequest-handler", from: "0.0.1")
]
```

Then add `URLRequestHandler` to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "URLRequestHandler", package: "swift-urlrequest-handler")
        ]
    )
]
```

## Usage

### Basic Request Handling

```swift
import URLRequestHandler
import Dependencies

struct MyAPI {
    @Dependency(\.defaultRequestHandler) var requestHandler
    
    func fetchUser(id: String) async throws -> User {
        let request = URLRequest(url: URL(string: "https://api.example.com/users/\(id)")!)
        
        return try await requestHandler(
            for: request,
            decodingTo: User.self
        )
    }
}

struct User: Decodable {
    let id: String
    let name: String
    let email: String
}
```

### Envelope Response Pattern

The handler automatically attempts to decode responses as envelope-wrapped first, then falls back to direct decoding:

```swift
// Handles this envelope response:
// {
//   "success": true,
//   "data": { "id": "123", "name": "John" },
//   "message": "User fetched successfully",
//   "timestamp": "2024-01-01T00:00:00Z"
// }

// And also handles direct response:
// { "id": "123", "name": "John" }

let user: User = try await requestHandler(
    for: request,
    decodingTo: User.self
)
```

### Custom JSON Decoder

```swift
var handler = URLRequest.Handler()
handler.decoder.dateDecodingStrategy = .secondsSince1970
handler.decoder.keyDecodingStrategy = .useDefaultKeys

let response = try await handler(
    for: request,
    decodingTo: Response.self
)
```

### Void Requests

For requests that don't return a response body:

```swift
let request = URLRequest(url: URL(string: "https://api.example.com/logout")!)
request.httpMethod = "POST"

try await requestHandler(for: request)
```

### Error Handling

```swift
do {
    let user = try await requestHandler(
        for: request,
        decodingTo: User.self
    )
} catch RequestError.httpError(let statusCode, let message) {
    print("HTTP Error \(statusCode): \(message)")
} catch RequestError.decodingError(let context) {
    print("Decoding failed: \(context.description)")
} catch RequestError.envelopeDataMissing {
    print("Envelope response contained no data")
} catch RequestError.invalidResponse {
    print("Invalid response from server")
}
```

### Testing

In tests, the handler automatically enables debug mode:

```swift
import URLRequestHandler
import DependenciesTestSupport
import Testing

@Test
func testAPICall() async throws {
    try await withDependencies {
        $0.defaultSession = { request in
            // Mock response
            let data = """
            {"id": "123", "name": "Test User"}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }
    } operation: {
        @Dependency(\.defaultRequestHandler) var handler
        
        let request = URLRequest(url: URL(string: "https://api.example.com/user")!)
        let user: User = try await handler(
            for: request,
            decodingTo: User.self
        )
        
        #expect(user.id == "123")
        #expect(user.name == "Test User")
    }
}
```

### Custom URLSession

Override the default session for custom configurations:

```swift
try await withDependencies {
    $0.defaultSession = { request in
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        return try await session.data(for: request)
    }
} operation: {
    // Your code using the custom session
}
```

## API Reference

### URLRequest.Handler

The main request handler with configurable options:

```swift
public struct Handler: Sendable {
    public var debug: Bool = false
    public var decoder: JSONDecoder
    
    public init(debug: Bool = false, decoder: JSONDecoder = Self.defaultDecoder)
}
```

### RequestError

Comprehensive error types for different failure scenarios:

```swift
public enum RequestError: Error, Equatable {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(DecodingContext)
    case envelopeDataMissing
}
```

### Envelope<T>

Generic envelope type for wrapped API responses:

```swift
public struct Envelope<T> {
    public let success: Bool
    public let data: T?
    public let message: String?
    public let timestamp: Date
}
```

## Testing

```bash
swift test
```

## Requirements

- Swift 6.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Dependencies

- [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) (1.9.2+)
- [swift-log](https://github.com/apple/swift-log) (1.0.0+)
- [swift-logger-dependencies](https://github.com/swift-foundations/swift-logger-dependencies)
- [xctest-dynamic-overlay](https://github.com/pointfreeco/xctest-dynamic-overlay) (1.4.3+)

## Related Packages

### Dependencies

- [swift-logger-dependencies](https://github.com/swift-foundations/swift-logger-dependencies): The focused Swift Logging × Dependencies integration.

### Used By

- [swift-mailgun-live](https://github.com/coenttb/swift-mailgun-live): A Swift package with live implementations for Mailgun.
- [swift-server-foundation](https://github.com/coenttb/swift-server-foundation): A Swift package with tools to simplify server development.

### Third-Party Dependencies

- [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies): A dependency management library for controlling dependencies in Swift.
- [pointfreeco/xctest-dynamic-overlay](https://github.com/pointfreeco/xctest-dynamic-overlay): Define XCTest assertion helpers directly in production code.

## License

This package is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

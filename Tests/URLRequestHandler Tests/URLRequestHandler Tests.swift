import Dependencies_Test_Support
import Foundation
import Testing

@testable import URLRequestHandler

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite
struct URLRequestHandlerTests {
    // MARK: - Basic Functionality Tests

    @Test
    func testSuccessfulDirectResponse() async throws {
        let mockData = Data(
            """
            {"id": "123", "name": "Test User", "email": "test@example.com"}
            """.utf8
        )

        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (mockData, response)
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
            #expect(user.email == "test@example.com")
        }
    }

    @Test
    func testSuccessfulEnvelopeResponse() async throws {
        let mockData = Data(
            """
            {
                "success": true,
                "data": {"id": "456", "name": "Envelope User", "email": "envelope@example.com"},
                "message": "User fetched successfully",
                "timestamp": "2024-01-01T00:00:00Z"
            }
            """.utf8
        )

        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (mockData, response)
            }
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = URLRequest(url: URL(string: "https://api.example.com/user")!)
            let user: User = try await handler(
                for: request,
                decodingTo: User.self
            )

            #expect(user.id == "456")
            #expect(user.name == "Envelope User")
            #expect(user.email == "envelope@example.com")
        }
    }

    @Test
    func testVoidRequest() async throws {
        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(), response)
            }
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = URLRequest(url: URL(string: "https://api.example.com/logout")!)

            // Should not throw
            try await handler(for: request)
        }
    }

    // MARK: - Error Handling Tests

    @Test
    func testHTTPError() async throws {
        let errorData = Data(
            """
            {"message": "User not found"}
            """.utf8
        )

        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (errorData, response)
            }
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = URLRequest(url: URL(string: "https://api.example.com/user/999")!)

            do {
                let _: User = try await handler(
                    for: request,
                    decodingTo: User.self
                )
                #expect(Bool(false), "Should have thrown an error")
            } catch let error as RequestError {
                if case .httpError(let statusCode, let message) = error {
                    #expect(statusCode == 404)
                    #expect(message == "User not found")
                } else {
                    #expect(Bool(false), "Wrong error type: \(error)")
                }
            }
        }
    }

    @Test
    func testDecodingError() async throws {
        let invalidData = Data(
            """
            {"invalid": "json structure"}
            """.utf8
        )

        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (invalidData, response)
            }
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = URLRequest(url: URL(string: "https://api.example.com/user")!)

            do {
                let _: User = try await handler(
                    for: request,
                    decodingTo: User.self
                )
                #expect(Bool(false), "Should have thrown a decoding error")
            } catch let error as RequestError {
                if case .decodingError(let context) = error {
                    #expect(context.attemptedType.contains("User"))
                    #expect(context.rawData?.contains("invalid") == true)
                } else {
                    #expect(Bool(false), "Wrong error type: \(error)")
                }
            }
        }
    }

    @Test
    func testEnvelopeWithNoData() async throws {
        let mockData = Data(
            """
            {
                "success": true,
                "data": null,
                "message": "No data available",
                "timestamp": "2024-01-01T00:00:00Z"
            }
            """.utf8
        )

        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (mockData, response)
            }
        } operation: {
            @Dependency(\.defaultRequestHandler) var handler

            let request = URLRequest(url: URL(string: "https://api.example.com/user")!)

            do {
                let _: User = try await handler(
                    for: request,
                    decodingTo: User.self
                )
                #expect(Bool(false), "Should have thrown envelopeDataMissing error")
            } catch RequestError.envelopeDataMissing {
                // Expected error
            }
        }
    }

    // MARK: - URLSession Dependency Tests

    @Test
    func testDefaultSessionKey() async throws {
        let mockData = Data("test".utf8)
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        try await withDependencies {
            $0.defaultSession = { request in
                #expect(request.url?.absoluteString == "https://example.com")
                return (mockData, mockResponse)
            }
        } operation: {
            @Dependency(\.defaultSession) var session

            let request = URLRequest(url: URL(string: "https://example.com")!)
            let (data, response) = try await session(request)

            #expect(data == mockData)
            #expect(response == mockResponse)
        }
    }

    // MARK: - Envelope Type Tests

    @Test
    func testEnvelopeDecoding() throws {
        let json = Data(
            """
            {
                "success": true,
                "data": {"value": "test"},
                "message": "Success",
                "timestamp": "2024-01-01T00:00:00Z"
            }
            """.utf8
        )

        struct TestData: Decodable {
            let value: String
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(Envelope<TestData>.self, from: json)

        #expect(envelope.success == true)
        #expect(envelope.data?.value == "test")
        #expect(envelope.message == "Success")
        #expect(envelope.timestamp != nil)
    }

    @Test
    func testEnvelopeEncoding() throws {
        struct TestData: Codable {
            let value: String
        }

        let envelope = Envelope(
            success: true,
            data: TestData(value: "test"),
            message: "Test message"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(envelope)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"value\":\"test\""))
        #expect(json.contains("\"message\":\"Test message\""))
        #expect(json.contains("\"timestamp\""))
    }

    // MARK: - Custom Decoder Tests

    @Test
    func testCustomDecoder() async throws {
        let mockData = Data(
            """
            {"user_id": "789", "user_name": "Snake Case User", "email_address": "snake@example.com"}
            """.utf8
        )

        try await withDependencies {
            $0.defaultSession = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (mockData, response)
            }
        } operation: {
            var handler = URLRequest.Handler()
            handler.decoder.keyDecodingStrategy = .convertFromSnakeCase

            struct SnakeCaseUser: Decodable {
                let userId: String
                let userName: String
                let emailAddress: String
            }

            let request = URLRequest(url: URL(string: "https://api.example.com/user")!)
            let user: SnakeCaseUser = try await handler(
                for: request,
                decodingTo: SnakeCaseUser.self
            )

            #expect(user.userId == "789")
            #expect(user.userName == "Snake Case User")
            #expect(user.emailAddress == "snake@example.com")
        }
    }
}

// MARK: - Test Models

private struct User: Decodable {
    let id: String
    let name: String
    let email: String
}

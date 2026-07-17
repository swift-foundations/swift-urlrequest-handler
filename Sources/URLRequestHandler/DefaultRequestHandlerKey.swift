import Dependencies
import Foundation
import Logger_Dependencies
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension URLRequest {
    /// A handler for performing URLRequest operations with structured error handling,
    /// logging, and configurable JSON decoding.
    ///
    /// This handler provides:
    /// - Automatic envelope/direct response decoding
    /// - Structured error reporting with context
    /// - Comprehensive logging with privacy considerations
    /// - Configurable JSON decoder
    /// - Integration with Swift Dependencies and Swift Logging
    public struct Handler: Sendable {
        public var debug = false
        public var decoder: JSONDecoder
        @Dependency(\.logger) var logger
        @Dependency(\.defaultSession) var session
        /// Initializes a new request handler.
        /// - Parameters:
        ///   - debug: Whether to enable debug logging. Defaults to false.
        ///   - decoder: The JSON decoder to use for response parsing. Defaults to defaultDecoder.
        public init(debug: Bool = false, decoder: JSONDecoder = Self.defaultDecoder) {
            self.debug = debug
            self.decoder = decoder
        }

        /// The default JSON decoder configuration with ISO8601 dates and snake_case key conversion.
        public static var defaultDecoder: JSONDecoder {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }

        /// Performs a URLRequest and decodes the response to the specified type.
        ///
        /// This method attempts to decode the response in two ways:
        /// 1. First as an Envelope<ResponseType> wrapper
        /// 2. If that fails, directly as ResponseType
        ///
        /// - Parameters:
        ///   - request: The URLRequest to perform
        ///   - type: The type to decode the response to
        ///   - fileID: Source location for error reporting
        ///   - filePath: Source file path for error reporting
        ///   - line: Source line number for error reporting
        ///   - column: Source column for error reporting
        /// - Returns: The decoded response of type ResponseType
        /// - Throws: RequestError for various failure scenarios
        public func callAsFunction<ResponseType: Decodable>(
            for request: URLRequest,
            decodingTo type: ResponseType.Type,
            fileID: StaticString = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: UInt = #column
        ) async throws -> ResponseType {
            guard request.url != nil else {
                logger.error("URLRequest has no URL (\(fileID):\(line))")
                throw RequestError.invalidResponse
            }

            let (data, _) = try await performRequest(request)

            if debug {
                logger.debug(
                    "Trying to decode response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode response data")"
                )
            }

            do {
                if debug {
                    logger.debug(
                        "Attempting to decode as Envelope<\(String(describing: ResponseType.self))>"
                    )
                }

                let envelope = try decodeResponse(
                    data: data,
                    as: Envelope<ResponseType>.self,
                    fileID: fileID,
                    filePath: filePath,
                    line: line,
                    column: column
                )

                if debug {
                    logger.debug("Envelope decoded successfully. Success: \(envelope.success)")
                }

                if let envelopeData = envelope.data {
                    if debug {
                        logger.debug("Returning envelope data")
                    }
                    return envelopeData
                }

                if debug {
                    logger.warning("Envelope data is nil, envelope response contained no data")
                }
                throw RequestError.envelopeDataMissing
            } catch RequestError.envelopeDataMissing {
                // Re-throw envelopeDataMissing without trying direct decode
                throw RequestError.envelopeDataMissing
            } catch {
                if debug {
                    logger.info(
                        "Envelope decode failed, attempting direct decode. Error: \(error.localizedDescription)"
                    )
                }

                // If envelope decode fails, try direct decode
                do {
                    let response = try decodeResponse(
                        data: data,
                        as: type,
                        fileID: fileID,
                        filePath: filePath,
                        line: line,
                        column: column
                    )

                    if debug {
                        logger.debug("Direct decode successful")
                    }
                    return response
                } catch let decodeError {
                    // If the error is already a RequestError, re-throw it directly
                    if let requestError = decodeError as? RequestError {
                        if debug {
                            logger.error("Direct decode failed with RequestError: \(requestError)")
                        }
                        throw requestError
                    }

                    // Only wrap non-RequestError errors
                    let rawDataString =
                        String(data: data, encoding: .utf8)
                        ?? "Unable to convert data to UTF-8 string"
                    let context = DecodingContext(
                        originalError: decodeError.localizedDescription,
                        attemptedType: String(reflecting: type),
                        fileID: String(describing: fileID),
                        line: line,
                        rawData: rawDataString
                    )
                    if debug {
                        logger.error("Direct decode failed: \(context.description)")
                    }

                    // Only report final decode failures if not in test environment
                    if !debug {
                        logger.error("Failed to decode response as \(type) (\(fileID):\(line))")
                    }
                    throw RequestError.decodingError(context)
                }
            }
        }

        /// Performs a URLRequest without expecting a decoded response (void requests).
        /// - Parameter request: The URLRequest to perform
        /// - Throws: RequestError for various failure scenarios
        public func callAsFunction(
            for request: URLRequest
        ) async throws {
            guard request.url != nil else {
                logger.error("URLRequest has no URL")
                throw RequestError.invalidResponse
            }

            let (_, _) = try await performRequest(request)
        }

        private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            if debug { logRequest(request) }

            let (data, response) = try await session(request)

            if debug { logResponse(response, data: data) }

            guard let httpResponse = response as? HTTPURLResponse else {
                if debug {
                    logger.error(
                        "Invalid Response - Expected HTTPURLResponse but got: \(String(describing: response))"
                    )
                }
                // Don't report issues in test environment (debug=true means test environment)
                if !debug {
                    logger.error("Received non-HTTP response: \(String(describing: response))")
                }
                throw RequestError.invalidResponse
            }

            try validateResponse(httpResponse, data: data)
            return (data, httpResponse)
        }

        private func decodeResponse<T: Decodable>(
            data: Data,
            as type: T.Type,
            fileID: StaticString = #fileID,
            filePath: StaticString = #filePath,
            line: UInt = #line,
            column: UInt = #column
        ) throws -> T {
            do {
                return try self.decoder.decode(type, from: data)
            } catch {
                let rawDataString =
                    String(data: data, encoding: .utf8) ?? "Unable to convert data to UTF-8 string"
                let context = DecodingContext(
                    originalError: error.localizedDescription,
                    attemptedType: String(reflecting: type),
                    fileID: String(describing: fileID),
                    line: line,
                    rawData: rawDataString
                )
                // Don't log an error here as this is often an expected failure (e.g., envelope vs direct decode attempts)
                throw RequestError.decodingError(context)
            }
        }

        private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
            guard (200...299).contains(response.statusCode) else {
                let errorMessage =
                    (try? JSONDecoder().decode(ErrorResponse.self, from: data).message)
                    ?? String(decoding: data, as: UTF8.self)

                let error = RequestError.httpError(
                    statusCode: response.statusCode,
                    message: errorMessage
                )

                if debug {
                    logger.error(
                        "HTTP Error - Status: \(response.statusCode), Message: \(errorMessage), Raw Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode error response")"
                    )
                }

                // Only report server errors (5xx) if not in test environment
                if response.statusCode >= 500 && !debug {
                    logger.error("Server error \(response.statusCode): \(errorMessage)")
                }

                throw error
            }
        }

        private func logRequest(_ request: URLRequest) {
            logger.info(
                "Request - URL: \(request.url?.absoluteString ?? "nil"), Method: \(request.httpMethod ?? "nil")"
            )

            if let headers = request.allHTTPHeaderFields {
                let sanitizedHeaders = headers.map { key, value in
                    let sanitizedValue =
                        key.lowercased().contains("authorization")
                            || key.lowercased().contains("token")
                        ? "*****" : value
                    return "\(key): \(sanitizedValue)"
                }.joined(separator: ", ")
                logger.debug("Request Headers: \(sanitizedHeaders)")
            }

            if let body = request.httpBody {
                logger.debug(
                    "Request Body: \(String(data: body, encoding: .utf8) ?? "Unable to decode body")"
                )
            }
        }

        private func logResponse(_ response: URLResponse, data: Data) {
            if let httpResponse = response as? HTTPURLResponse {
                logger.info("Response - Status: \(httpResponse.statusCode)")

                let headers = httpResponse.allHeaderFields.map { key, value in
                    "\(key): \(value)"
                }.joined(separator: ", ")
                logger.debug("Response Headers: \(headers)")
            }
            logger.debug(
                "Response Body: \(String(data: data, encoding: .utf8) ?? "Unable to decode response body")"
            )
        }
    }
}

extension Dependency.Values {
    public var defaultRequestHandler: URLRequest.Handler {
        get { self[URLRequest.Handler.self] }
        set { self[URLRequest.Handler.self] = newValue }
    }
}

extension URLRequest.Handler: Dependency.Key.Test {
    public static var testValue: Self { .init(debug: true) }
}

/// Standard error response format from the server.
struct ErrorResponse: Decodable {
    let message: String
}

public enum RequestError: Error, Equatable {
    /// The server returned a non-HTTP response
    case invalidResponse
    /// The server returned an HTTP error status code
    case httpError(statusCode: Int, message: String)
    /// Failed to decode the response data
    case decodingError(DecodingContext)
    /// The envelope response was successful but contained no data
    case envelopeDataMissing

    public var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .decodingError(let context):
            return "Failed to decode response: \(context.description)"
        case .envelopeDataMissing:
            return "Envelope response contained no data"
        }
    }
}

/// Context information for decoding errors.
public struct DecodingContext: Equatable, Sendable {
    /// The original error message from the decoder
    public let originalError: String
    /// The type that was being decoded
    public let attemptedType: String
    /// The source file where the error occurred
    public let fileID: String
    /// The line number where the error occurred
    public let line: UInt
    /// The raw data that failed to decode (for debugging)
    public let rawData: String?

    public init(
        originalError: String,
        attemptedType: String,
        fileID: String,
        line: UInt,
        rawData: String? = nil
    ) {
        self.originalError = originalError
        self.attemptedType = attemptedType
        self.fileID = fileID
        self.line = line
        self.rawData = rawData
    }

    public var description: String {
        var desc = "\(originalError) (attempted type: \(attemptedType) at \(fileID):\(line))"
        if let rawData = rawData {
            desc += "\nRaw data received: \(rawData)"
        }
        return desc
    }
}

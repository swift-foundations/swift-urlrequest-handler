//
//  File.swift
//  coenttb-web
//
//  Created by Coen ten Thije Boonkkamp on 23/12/2024.
//

import Dependencies
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum DefaultSessionKey: Sendable, Dependency.Key {
    // reason: this is a test-mockable transport seam — `URLSession.shared.data(for:)`
    // itself throws untyped `any Error` (network errors are diverse: `URLError`,
    // POSIXError, etc.), and test overrides must be free to throw arbitrary error
    // types, so the closure type cannot be pinned to one concrete `Error`. The
    // caller (`URLRequestHandler.Handler.performRequest`) wraps this boundary's
    // failure into the typed `RequestError.sessionError` immediately.
    // swiftlint:disable:next typed_throws_required
    public static let testValue: @Sendable (URLRequest) async throws -> (Data, URLResponse) = Self
        .liveValue
    // swiftlint:disable:next typed_throws_required
    public static let liveValue: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        request in try await URLSession.shared.data(for: request)
    }
}

extension Dependency.Values {
    // swiftlint:disable:next typed_throws_required
    public var defaultSession: @Sendable (URLRequest) async throws -> (Data, URLResponse) {
        get { self[DefaultSessionKey.self] }
        set { self[DefaultSessionKey.self] = newValue }
    }
}

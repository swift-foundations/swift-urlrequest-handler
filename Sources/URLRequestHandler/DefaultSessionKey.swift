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
    public static let testValue: @Sendable (URLRequest) async throws -> (Data, URLResponse) = Self
        .liveValue
    public static let liveValue: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        request in try await URLSession.shared.data(for: request)
    }
}

extension Dependency.Values {
    public var defaultSession: @Sendable (URLRequest) async throws -> (Data, URLResponse) {
        get { self[DefaultSessionKey.self] }
        set { self[DefaultSessionKey.self] = newValue }
    }
}

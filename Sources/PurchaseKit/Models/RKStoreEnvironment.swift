//
//  RKStoreEnvironment.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import StoreKit

/// The App Store environment a transaction or app purchase was signed in.
///
/// Mirrors `AppStore.Environment`. A server that grants purchases should reject sandbox and
/// Xcode transactions in production; this is how the device side can tell them apart too.
///
/// A raw-value struct rather than an enum, the same pattern StoreKit uses, so an environment
/// Apple adds later arrives as a value instead of breaking an exhaustive `switch`. The raw
/// values are StoreKit's own, so such a value reads exactly as StoreKit reported it.
public struct StoreEnvironment: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The live App Store: real money.
    public static let production = StoreEnvironment(rawValue: "Production")
    /// The App Store sandbox, used by TestFlight and sandbox accounts.
    public static let sandbox = StoreEnvironment(rawValue: "Sandbox")
    /// Local StoreKit testing in Xcode with a configuration file.
    public static let xcode = StoreEnvironment(rawValue: "Xcode")

    init(_ environment: AppStore.Environment) {
        self.init(rawValue: environment.rawValue)
    }
}

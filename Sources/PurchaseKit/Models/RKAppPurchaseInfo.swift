//
//  RKAppPurchaseInfo.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

public import Foundation
import StoreKit

/// How and when the customer got the app itself.
///
/// The usual reason to ask is a move from a paid app to free with in-app purchases: customers
/// who bought the app before the switch should keep what they paid for, and
/// ``originalAppVersion`` is what tells them apart.
///
/// Mirrors `AppTransaction`, which cannot be built outside StoreKit.
public struct AppPurchaseInfo: Sendable {

    // MARK: Properties
    /// The app version the customer first acquired: `CFBundleVersion` on iOS, visionOS,
    /// watchOS and tvOS, `CFBundleShortVersionString` on macOS.
    ///
    /// In the sandbox this is always `"1.0"`, so test the paid-to-free logic with a value
    /// built by hand rather than against the sandbox.
    public let originalAppVersion: String
    /// When the customer first acquired the app.
    public let originalPurchaseDate: Date
    /// The app version the transaction was signed for.
    public let appVersion: String
    /// The App Store environment that signed the transaction.
    public let environment: StoreEnvironment
    /// The app transaction as the App Store signed it, for your server to verify.
    public let jwsRepresentation: String?

    // MARK: Initial methods

    /// Creates a value that is not backed by StoreKit, for tests, previews and mocks.
    public init(
        originalAppVersion: String,
        originalPurchaseDate: Date,
        appVersion: String,
        environment: StoreEnvironment = .production,
        jwsRepresentation: String? = nil
    ) {
        self.originalAppVersion = originalAppVersion
        self.originalPurchaseDate = originalPurchaseDate
        self.appVersion = appVersion
        self.environment = environment
        self.jwsRepresentation = jwsRepresentation
    }

    /// Reads a verified StoreKit app transaction. Verification is the caller's job, as it is
    /// for ``StoreTransaction``.
    init(appTransaction: AppTransaction, jwsRepresentation: String?) {
        self.init(
            originalAppVersion: appTransaction.originalAppVersion,
            originalPurchaseDate: appTransaction.originalPurchaseDate,
            appVersion: appTransaction.appVersion,
            environment: StoreEnvironment(appTransaction.environment),
            jwsRepresentation: jwsRepresentation
        )
    }
}

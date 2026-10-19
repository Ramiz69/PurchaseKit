//
//  AppPurchaseInfoTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import Foundation
import StoreKit
import Testing
@testable import RKPurchaseKit

/// Covers the small values that describe the app purchase, its environment and a refund
/// request outcome.
@Suite("AppPurchaseInfo", .timeLimit(.minutes(1)))
struct AppPurchaseInfoTests {

    /// `AppTransaction` cannot be built outside StoreKit; this is what a paid-to-free check
    /// gets tested against instead.
    @Test("can be constructed without StoreKit")
    func buildsWithoutStoreKit() {
        let firstLaunch = Date(timeIntervalSince1970: 1_500_000_000)

        let info = AppPurchaseInfo(
            originalAppVersion: "1.4",
            originalPurchaseDate: firstLaunch,
            appVersion: "4.0",
            environment: .sandbox,
            jwsRepresentation: "app.jws"
        )

        #expect(info.originalAppVersion == "1.4")
        #expect(info.originalPurchaseDate == firstLaunch)
        #expect(info.appVersion == "4.0")
        #expect(info.environment == .sandbox)
        #expect(info.jwsRepresentation == "app.jws")
    }

    @Test("environment and signature default to production and absent")
    func appliesDefaults() {
        let info = AppPurchaseInfo(originalAppVersion: "1.0", originalPurchaseDate: .now, appVersion: "1.0")

        #expect(info.environment == .production)
        #expect(info.jwsRepresentation == nil)
    }

    // MARK: StoreEnvironment

    @Test("environments carry StoreKit's raw values")
    func matchesStoreKitEnvironments() {
        #expect(StoreEnvironment.production.rawValue == AppStore.Environment.production.rawValue)
        #expect(StoreEnvironment.sandbox.rawValue == AppStore.Environment.sandbox.rawValue)
        #expect(StoreEnvironment.xcode.rawValue == AppStore.Environment.xcode.rawValue)
    }

    @Test("an unfamiliar environment is kept as reported")
    func keepsUnknownEnvironment() {
        let future = StoreEnvironment(AppStore.Environment(rawValue: "Preview"))

        #expect(future.rawValue == "Preview")
        #expect(![StoreEnvironment.production, .sandbox, .xcode].contains(future))
    }

    // MARK: RefundRequestStatus

    @Test(
        "maps each refund request outcome",
        arguments: [
            (Transaction.RefundRequestStatus.success, RefundRequestStatus.success),
            (.userCancelled, .userCancelled)
        ]
    )
    func mapsRefundRequestStatus(storeKitStatus: Transaction.RefundRequestStatus, expected: RefundRequestStatus) {
        #expect(RefundRequestStatus(storeKitStatus) == expected)
    }
}

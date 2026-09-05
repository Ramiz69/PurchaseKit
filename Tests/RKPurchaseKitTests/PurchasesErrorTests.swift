//
//  PurchasesErrorTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import Testing
@testable import RKPurchaseKit

/// Covers the conformances that make ``PurchasesError`` usable by callers.
@Suite("PurchasesError", .timeLimit(.minutes(1)))
struct PurchasesErrorTests {

    @Test("matching cases compare equal", arguments: [
        PurchasesError.notConfigured,
        .purchaseCancelled,
        .purchasePending,
        .verificationFailed,
        .unhandledPurchaseResult,
        .invalidProductID("pro.monthly")
    ])
    func equatesMatchingCases(error: PurchasesError) {
        #expect(error == error)
    }

    @Test("different cases do not compare equal")
    func separatesDifferentCases() {
        #expect(PurchasesError.purchaseCancelled != PurchasesError.purchasePending)
        #expect(PurchasesError.notConfigured != PurchasesError.verificationFailed)
    }

    @Test("the associated identifier participates in equality")
    func comparesAssociatedIdentifier() {
        #expect(PurchasesError.invalidProductID("a") == PurchasesError.invalidProductID("a"))
        #expect(PurchasesError.invalidProductID("a") != PurchasesError.invalidProductID("b"))
    }

    @Test("a wrapped error participates in equality")
    func comparesWrappedError() {
        let underlying = NSError(domain: "test", code: 7)
        let other = NSError(domain: "test", code: 8)

        #expect(PurchasesError.unknown(underlying) == PurchasesError.unknown(underlying))
        #expect(PurchasesError.unknown(underlying) != PurchasesError.unknown(other))
    }

    @Test("every case describes itself", arguments: [
        PurchasesError.notConfigured,
        .purchaseCancelled,
        .purchasePending,
        .verificationFailed,
        .unhandledPurchaseResult,
        .invalidProductID("pro.monthly"),
        .unknown(NSError(domain: "test", code: 1))
    ])
    func describesEveryCase(error: PurchasesError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    /// Without `LocalizedError`, `localizedDescription` reports Foundation's generic fallback
    /// rather than anything worth showing or logging.
    ///
    /// `unknown` is excluded on purpose: its description belongs to the error it wraps, and
    /// when that error carries none, the fallback is the best available answer.
    @Test("the SDK's own cases use their own wording", arguments: [
        PurchasesError.notConfigured,
        .purchaseCancelled,
        .purchasePending,
        .verificationFailed,
        .unhandledPurchaseResult,
        .invalidProductID("pro.monthly")
    ])
    func avoidsTheGenericFallback(error: PurchasesError) {
        #expect(!error.localizedDescription.contains("The operation couldn’t be completed"))
    }

    @Test("the invalid identifier appears in its description")
    func namesTheInvalidIdentifier() {
        let error = PurchasesError.invalidProductID("pro.monthly")

        #expect(error.localizedDescription.contains("pro.monthly"))
    }

    @Test("a wrapped error describes itself through the wrapper")
    func forwardsWrappedDescription() {
        let underlying = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network unreachable"]
        )

        #expect(PurchasesError.unknown(underlying).localizedDescription == "Network unreachable")
    }
}

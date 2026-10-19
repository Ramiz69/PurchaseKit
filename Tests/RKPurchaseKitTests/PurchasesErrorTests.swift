//
//  PurchasesErrorTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit
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
        .productUnavailable,
        .purchaseNotAllowed,
        .invalidQuantity,
        .ineligibleForOffer,
        .invalidOffer,
        .paymentMethodBindingRequired,
        .networkUnavailable,
        .notAvailableInStorefront,
        .notEntitled,
        .unsupported,
        .offerNotFound("winback.half"),
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
        #expect(PurchasesError.offerNotFound("a") == PurchasesError.offerNotFound("a"))
        #expect(PurchasesError.offerNotFound("a") != PurchasesError.offerNotFound("b"))
        #expect(PurchasesError.offerNotFound("a") != PurchasesError.invalidProductID("a"))
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
        .productUnavailable,
        .purchaseNotAllowed,
        .invalidQuantity,
        .ineligibleForOffer,
        .invalidOffer,
        .paymentMethodBindingRequired,
        .networkUnavailable,
        .notAvailableInStorefront,
        .notEntitled,
        .unsupported,
        .offerNotFound("winback.half"),
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
        .productUnavailable,
        .purchaseNotAllowed,
        .invalidQuantity,
        .ineligibleForOffer,
        .invalidOffer,
        .paymentMethodBindingRequired,
        .networkUnavailable,
        .notAvailableInStorefront,
        .notEntitled,
        .unsupported,
        .offerNotFound("winback.half"),
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

    @Test("the missing offer identifier appears in its description")
    func namesTheMissingOffer() {
        #expect(PurchasesError.offerNotFound("winback.half").localizedDescription.contains("winback.half"))
    }

    // MARK: Mapping

    @Test(
        "maps StoreKit purchase errors",
        arguments: [
            (Product.PurchaseError.productUnavailable, PurchasesError.productUnavailable),
            (.purchaseNotAllowed, .purchaseNotAllowed),
            (.invalidQuantity, .invalidQuantity),
            (.ineligibleForOffer, .ineligibleForOffer),
            (.invalidOfferIdentifier, .invalidOffer),
            (.invalidOfferPrice, .invalidOffer),
            (.invalidOfferSignature, .invalidOffer),
            (.missingOfferParameters, .invalidOffer)
        ]
    )
    func mapsPurchaseErrors(storeKitError: Product.PurchaseError, expected: PurchasesError) {
        #expect(PurchasesError.mapping(storeKitError) == expected)
    }

    /// The case is new in 26.5, so it can only be built where the running system has it.
    @Test("maps the payment method binding error where the system has it")
    func mapsPaymentMethodBinding() {
        guard #available(iOS 26.5, macOS 26.5, tvOS 26.5, watchOS 26.5, visionOS 26.5, *) else {
            return
        }

        let error = Product.PurchaseError.paymentMethodBindingConfigurationRequired

        #expect(PurchasesError.mapping(error) == .paymentMethodBindingRequired)
    }

    @Test(
        "maps StoreKit framework errors",
        arguments: [
            (StoreKitError.userCancelled, PurchasesError.purchaseCancelled),
            (.networkError(URLError(.notConnectedToInternet)), .networkUnavailable),
            (.notAvailableInStorefront, .notAvailableInStorefront),
            (.notEntitled, .notEntitled),
            (.unsupported, .unsupported)
        ]
    )
    func mapsStoreKitErrors(storeKitError: StoreKitError, expected: PurchasesError) {
        #expect(PurchasesError.mapping(storeKitError) == expected)
    }

    /// Anything without a dedicated case is kept, not replaced, so its own description and
    /// identity survive for logging.
    @Test("wraps an unrecognised StoreKit error instead of discarding it")
    func wrapsUnknownStoreKitError() {
        let mapped = PurchasesError.mapping(StoreKitError.unknown)

        guard case .unknown(let wrapped) = mapped else {
            Issue.record("expected .unknown, got \(mapped)")
            return
        }
        #expect(wrapped is StoreKitError)
    }

    @Test("wraps a foreign error")
    func wrapsForeignError() {
        let underlying = NSError(domain: "test", code: 3)

        #expect(PurchasesError.mapping(underlying) == .unknown(underlying))
    }

    /// Public entry points may wrap errors thrown by inner calls that already wrapped them;
    /// a second pass must not bury the real case inside `.unknown`.
    @Test("an existing PurchasesError passes through unchanged", arguments: [
        PurchasesError.purchaseCancelled,
        .offerNotFound("winback.half"),
        .invalidProductID("pro.monthly"),
        .unknown(NSError(domain: "test", code: 4))
    ])
    func passesThroughOwnErrors(error: PurchasesError) {
        #expect(PurchasesError.mapping(error) == error)
        #expect(PurchasesError.mapping(PurchasesError.mapping(error)) == error)
    }
}

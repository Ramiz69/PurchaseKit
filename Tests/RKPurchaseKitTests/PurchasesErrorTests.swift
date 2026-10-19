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

/// Covers the conformances and matching rules that make ``PurchasesError`` usable by callers.
@Suite("PurchasesError", .timeLimit(.minutes(1)))
struct PurchasesErrorTests {

    /// Every code the SDK defines; kept in one place so a new code cannot be forgotten by
    /// one test and covered by another.
    static let allCodes: [PurchasesError.Code] = [
        .notConfigured,
        .invalidProductID,
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
        .offerNotFound,
        .unknown
    ]

    /// The codes whose description is the SDK's own wording rather than a wrapped error's.
    static let ownWordingCodes = allCodes.filter { $0 != .unknown }

    private struct ForeignError: Error {}

    private static func fail(with error: any Error) throws {
        throw error
    }

    // MARK: Codes

    /// Raw values are what a caller logs or sends to analytics, so two codes sharing one
    /// would make them indistinguishable there.
    @Test("every code has its own raw value")
    func codesAreDistinct() {
        #expect(Set(Self.allCodes).count == Self.allCodes.count)
        #expect(Set(Self.allCodes.map(\.rawValue)).count == Self.allCodes.count)
    }

    @Test("the static shortcuts are the codes themselves")
    func shortcutsMatchCodes() {
        let shortcuts: [PurchasesError.Code] = [
            PurchasesError.notConfigured,
            PurchasesError.invalidProductID,
            PurchasesError.purchaseCancelled,
            PurchasesError.purchasePending,
            PurchasesError.verificationFailed,
            PurchasesError.unhandledPurchaseResult,
            PurchasesError.productUnavailable,
            PurchasesError.purchaseNotAllowed,
            PurchasesError.invalidQuantity,
            PurchasesError.ineligibleForOffer,
            PurchasesError.invalidOffer,
            PurchasesError.paymentMethodBindingRequired,
            PurchasesError.networkUnavailable,
            PurchasesError.notAvailableInStorefront,
            PurchasesError.notEntitled,
            PurchasesError.unsupported,
            PurchasesError.offerNotFound,
            PurchasesError.unknown
        ]

        #expect(shortcuts == Self.allCodes)
    }

    /// A code added in a later release must still be representable, which is the reason the
    /// type is a struct.
    @Test("an unfamiliar code is kept as given")
    func keepsUnfamiliarCode() {
        let code = PurchasesError.Code(rawValue: "futureFailure")

        #expect(code.rawValue == "futureFailure")
        #expect(!Self.allCodes.contains(code))
        #expect(PurchasesError(code).code == code)
    }

    @Test("the initializer stores every field")
    func storesFields() {
        let underlying = NSError(domain: "test", code: 2)
        let error = PurchasesError(.unknown, productID: "a", offerID: "b", underlyingError: underlying)

        #expect(error.code == .unknown)
        #expect(error.productID == "a")
        #expect(error.offerID == "b")
        #expect(error.underlyingError as NSError? == underlying)

        let bare = PurchasesError(.purchasePending)
        #expect(bare.productID == nil)
        #expect(bare.offerID == nil)
        #expect(bare.underlyingError == nil)
    }

    // MARK: Catch patterns

    /// The 3.x way of handling cancellation has to keep compiling and matching.
    @Test("a catch clause matches a code through the static shortcut")
    func catchMatchesShortcut() {
        do {
            try Self.fail(with: PurchasesError(.purchaseCancelled))
            Issue.record("expected a throw")
        } catch PurchasesError.purchasePending {
            Issue.record("matched the wrong code")
        } catch PurchasesError.purchaseCancelled {
            // Expected.
        } catch {
            Issue.record("did not match: \(error)")
        }
    }

    @Test("a catch clause matches a code whatever else the error carries")
    func catchMatchesRegardlessOfDetails() {
        do {
            try Self.fail(with: PurchasesError(.invalidProductID, productID: "pro.monthly"))
            Issue.record("expected a throw")
        } catch PurchasesError.invalidProductID {
            // Expected.
        } catch {
            Issue.record("did not match: \(error)")
        }
    }

    @Test("a catch clause can bind the error and compare its code")
    func catchBindsAndComparesCode() {
        do {
            try Self.fail(with: PurchasesError(.networkUnavailable))
            Issue.record("expected a throw")
        } catch let error as PurchasesError where error.code == .purchaseCancelled {
            Issue.record("matched the wrong code: \(error)")
        } catch let error as PurchasesError where error.code == .networkUnavailable {
            #expect(error.underlyingError == nil)
        } catch {
            Issue.record("did not match: \(error)")
        }
    }

    /// Matching casts the thrown error; anything else must fall through to later clauses
    /// rather than match by accident.
    @Test("an error that is not a PurchasesError matches no code")
    func catchIgnoresForeignErrors() {
        do {
            try Self.fail(with: ForeignError())
            Issue.record("expected a throw")
        } catch PurchasesError.unknown {
            Issue.record("a foreign error matched .unknown")
        } catch PurchasesError.purchaseCancelled {
            Issue.record("a foreign error matched .purchaseCancelled")
        } catch is ForeignError {
            // Expected.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        #expect(!(PurchasesError.Code.unknown ~= StoreKitError.userCancelled))
        #expect(PurchasesError.Code.purchaseCancelled ~= PurchasesError(.purchaseCancelled))
    }

    // MARK: Equatable

    @Test("equal fields compare equal", arguments: allCodes)
    func equatesMatchingErrors(code: PurchasesError.Code) {
        #expect(PurchasesError(code) == PurchasesError(code))
    }

    @Test("different codes do not compare equal")
    func separatesDifferentCodes() {
        for lhs in Self.allCodes {
            for rhs in Self.allCodes where rhs != lhs {
                #expect(PurchasesError(lhs) != PurchasesError(rhs))
            }
        }
    }

    @Test("the identifiers participate in equality")
    func comparesIdentifiers() {
        #expect(PurchasesError(.invalidProductID, productID: "a") == PurchasesError(.invalidProductID, productID: "a"))
        #expect(PurchasesError(.invalidProductID, productID: "a") != PurchasesError(.invalidProductID, productID: "b"))
        #expect(PurchasesError(.invalidProductID, productID: "a") != PurchasesError(.invalidProductID))
        #expect(PurchasesError(.offerNotFound, offerID: "a") == PurchasesError(.offerNotFound, offerID: "a"))
        #expect(PurchasesError(.offerNotFound, offerID: "a") != PurchasesError(.offerNotFound, offerID: "b"))
        #expect(PurchasesError(.offerNotFound, offerID: "a") != PurchasesError(.invalidProductID, productID: "a"))
    }

    @Test("the underlying error participates in equality")
    func comparesUnderlyingError() {
        let underlying = NSError(domain: "test", code: 7)
        let other = NSError(domain: "test", code: 8)

        #expect(PurchasesError(.unknown, underlyingError: underlying) == PurchasesError(.unknown, underlyingError: underlying))
        #expect(PurchasesError(.unknown, underlyingError: underlying) != PurchasesError(.unknown, underlyingError: other))
        #expect(PurchasesError(.unknown, underlyingError: underlying) != PurchasesError(.unknown))
        #expect(PurchasesError(.unknown) != PurchasesError(.unknown, underlyingError: underlying))
    }

    // MARK: LocalizedError

    @Test("every code describes itself", arguments: allCodes)
    func describesEveryCode(code: PurchasesError.Code) {
        #expect(PurchasesError(code).errorDescription?.isEmpty == false)
    }

    /// Without `LocalizedError`, `localizedDescription` reports Foundation's generic fallback
    /// rather than anything worth showing or logging.
    ///
    /// `unknown` is excluded on purpose: its description belongs to the error it wraps, and
    /// when that error carries none, the fallback is the best available answer.
    @Test("the SDK's own codes use their own wording", arguments: ownWordingCodes)
    func avoidsTheGenericFallback(code: PurchasesError.Code) {
        #expect(!PurchasesError(code).localizedDescription.contains("The operation couldn’t be completed"))
    }

    @Test("every code has wording of its own", arguments: ownWordingCodes)
    func wordsEveryCodeDistinctly(code: PurchasesError.Code) {
        let others = Self.ownWordingCodes.filter { $0 != code }.map { PurchasesError($0).errorDescription }

        #expect(!others.contains(PurchasesError(code).errorDescription))
    }

    @Test("the invalid identifier appears in its description")
    func namesTheInvalidIdentifier() {
        let error = PurchasesError(.invalidProductID, productID: "pro.monthly")

        #expect(error.localizedDescription.contains("pro.monthly"))
    }

    @Test("the missing offer identifier appears in its description")
    func namesTheMissingOffer() {
        let error = PurchasesError(.offerNotFound, offerID: "winback.half")

        #expect(error.localizedDescription.contains("winback.half"))
    }

    @Test("an unknown error describes itself through the wrapped error")
    func forwardsWrappedDescription() {
        let underlying = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network unreachable"]
        )

        #expect(PurchasesError(.unknown, underlyingError: underlying).localizedDescription == "Network unreachable")
    }

    /// A translated StoreKit error keeps the SDK's wording: the point of the code is that the
    /// caller does not have to interpret StoreKit's.
    @Test("a translated error keeps the SDK's wording")
    func keepsOwnWordingWhenTranslated() {
        let error = PurchasesError.mapping(StoreKitError.notEntitled)

        #expect(error.errorDescription == PurchasesError(.notEntitled).errorDescription)
    }

    @Test("an unfamiliar code still describes itself")
    func describesUnfamiliarCode() {
        let code = PurchasesError.Code(rawValue: "futureFailure")
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Wrapped"])

        #expect(PurchasesError(code).localizedDescription.contains("futureFailure"))
        #expect(PurchasesError(code, underlyingError: underlying).localizedDescription == "Wrapped")
    }

    // MARK: Mapping

    @Test(
        "maps StoreKit purchase errors",
        arguments: [
            (Product.PurchaseError.productUnavailable, PurchasesError.Code.productUnavailable),
            (.purchaseNotAllowed, .purchaseNotAllowed),
            (.invalidQuantity, .invalidQuantity),
            (.ineligibleForOffer, .ineligibleForOffer),
            (.invalidOfferIdentifier, .invalidOffer),
            (.invalidOfferPrice, .invalidOffer),
            (.invalidOfferSignature, .invalidOffer),
            (.missingOfferParameters, .invalidOffer)
        ]
    )
    func mapsPurchaseErrors(storeKitError: Product.PurchaseError, expected: PurchasesError.Code) {
        let mapped = PurchasesError.mapping(storeKitError)

        #expect(mapped.code == expected)
        #expect(mapped == PurchasesError(expected, underlyingError: storeKitError))
        #expect(mapped.underlyingError as? Product.PurchaseError == storeKitError)
    }

    /// The case is new in 26.5, so it can only be built where the running system has it.
    @Test("maps the payment method binding error where the system has it")
    func mapsPaymentMethodBinding() {
        guard #available(iOS 26.5, macOS 26.5, tvOS 26.5, watchOS 26.5, visionOS 26.5, *) else {
            return
        }

        let error = Product.PurchaseError.paymentMethodBindingConfigurationRequired

        #expect(PurchasesError.mapping(error).code == .paymentMethodBindingRequired)
    }

    @Test(
        "maps StoreKit framework errors",
        arguments: [
            (StoreKitError.userCancelled, PurchasesError.Code.purchaseCancelled),
            (.networkError(URLError(.notConnectedToInternet)), .networkUnavailable),
            (.notAvailableInStorefront, .notAvailableInStorefront),
            (.notEntitled, .notEntitled),
            (.unsupported, .unsupported)
        ]
    )
    func mapsStoreKitErrors(storeKitError: StoreKitError, expected: PurchasesError.Code) {
        let mapped = PurchasesError.mapping(storeKitError)

        #expect(mapped.code == expected)
        #expect(mapped.underlyingError is StoreKitError)
    }

    /// Cancellation reported through `StoreKitError` must be caught by the same clause as the
    /// one reported through `Product.PurchaseResult`.
    @Test("a translated cancellation matches the cancellation catch clause")
    func translatedCancellationMatches() {
        do {
            try Self.fail(with: PurchasesError.mapping(StoreKitError.userCancelled))
            Issue.record("expected a throw")
        } catch PurchasesError.purchaseCancelled {
            // Expected.
        } catch {
            Issue.record("did not match: \(error)")
        }
    }

    /// Anything without a dedicated code is kept, not replaced, so its own description and
    /// identity survive for logging.
    @Test("wraps an unrecognised StoreKit error instead of discarding it")
    func wrapsUnknownStoreKitError() {
        let mapped = PurchasesError.mapping(StoreKitError.unknown)

        #expect(mapped.code == .unknown)
        #expect(mapped.underlyingError is StoreKitError)
    }

    @Test("wraps a foreign error")
    func wrapsForeignError() {
        let underlying = NSError(domain: "test", code: 3)

        #expect(PurchasesError.mapping(underlying) == PurchasesError(.unknown, underlyingError: underlying))
    }

    /// Public entry points may wrap errors thrown by inner calls that already wrapped them;
    /// a second pass must not bury the real code inside `.unknown`.
    @Test("an existing PurchasesError passes through unchanged", arguments: [
        PurchasesError(.purchaseCancelled),
        PurchasesError(.offerNotFound, offerID: "winback.half"),
        PurchasesError(.invalidProductID, productID: "pro.monthly"),
        PurchasesError(.unknown, underlyingError: NSError(domain: "test", code: 4)),
        PurchasesError.mapping(StoreKitError.networkError(URLError(.timedOut)))
    ])
    func passesThroughOwnErrors(error: PurchasesError) {
        #expect(PurchasesError.mapping(error) == error)
        #expect(PurchasesError.mapping(PurchasesError.mapping(error)) == error)
    }
}

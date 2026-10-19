//
//  RKPurchasesError.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

public import Foundation
import StoreKit

/// All error cases thrown by the SDK.
///
/// An enum rather than an open struct because callers switch over it to choose what to show.
/// The trade-off is that a new case is a breaking change, which is part of why 4.0 is a major
/// release. Errors this build does not recognise still arrive, wrapped in ``unknown(_:)``.
/// See <doc:PurchasesError>
public enum PurchasesError: Error, Sendable {
    case notConfigured
    case invalidProductID(String)
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    /// StoreKit returned a purchase result this SDK does not handle.
    ///
    /// `Product.PurchaseResult` is non-frozen, so a newer StoreKit can report an outcome
    /// that predates this build.
    case unhandledPurchaseResult
    /// The product is not available for purchase right now, for example because it was
    /// removed from sale in App Store Connect.
    case productUnavailable
    /// The account is not allowed to make purchases, usually because of Screen Time or
    /// device management restrictions. Retrying will not help; explain instead.
    case purchaseNotAllowed
    /// The requested quantity is outside what the App Store accepts.
    case invalidQuantity
    /// The account is not eligible for the offer that was requested.
    case ineligibleForOffer
    /// The offer in ``PurchaseOptions`` was rejected: unknown identifier, wrong price, bad
    /// signature or missing parameters.
    ///
    /// StoreKit reports these four separately, but every one of them means the offer was
    /// built or signed wrongly on your side, and the remedy is the same, so they share a case.
    case invalidOffer
    /// The App Store needs a payment method set up for this kind of purchase before it
    /// can go ahead. Reported by StoreKit from OS 26.5.
    case paymentMethodBindingRequired
    /// The App Store could not be reached.
    ///
    /// Separate from ``unknown(_:)`` because it is the one failure worth an automatic retry
    /// or a "check your connection" message.
    case networkUnavailable
    /// The product is not sold in the account's storefront.
    case notAvailableInStorefront
    /// The app is not entitled to the StoreKit feature it called, usually a missing
    /// capability or entitlement in the app's configuration.
    case notEntitled
    /// The device or OS does not support the requested operation.
    case unsupported
    /// The win-back offer identifier in ``PurchaseOptions/winBackOfferID`` is not one of the
    /// product's win-back offers.
    ///
    /// Raised by the kit before StoreKit is asked, because StoreKit takes the offer itself,
    /// not its identifier, and there is nothing to pass for an identifier that matches none.
    case offerNotFound(String)
    case unknown(any Error)
}

// MARK: - Mapping

extension PurchasesError {
    /// Translates an error thrown by StoreKit into the SDK's vocabulary.
    ///
    /// Callers should not need to import StoreKit and know its two error enums to tell a
    /// network failure from a disallowed purchase, so every public entry point funnels thrown
    /// errors through here. Idempotent: an error that already is a `PurchasesError` passes
    /// through unchanged, so wrapping twice on nested calls is harmless.
    static func mapping(_ error: any Error) -> PurchasesError {
        if let error = error as? PurchasesError {
            return error
        }
        if let error = error as? Product.PurchaseError {
            return mapping(error)
        }
        if let error = error as? StoreKitError {
            return mapping(error)
        }

        return .unknown(error)
    }

    private static func mapping(_ error: Product.PurchaseError) -> PurchasesError {
        switch error {
        case .productUnavailable:
            return .productUnavailable
        case .purchaseNotAllowed:
            return .purchaseNotAllowed
        case .invalidQuantity:
            return .invalidQuantity
        case .ineligibleForOffer:
            return .ineligibleForOffer
        case .invalidOfferIdentifier, .invalidOfferPrice, .invalidOfferSignature, .missingOfferParameters:
            return .invalidOffer
        default:
            // The binding case is new in 26.5 and the deployment target is 26.0, so it cannot
            // be named in a pattern; compare under an availability check instead.
            if #available(iOS 26.5, macOS 26.5, tvOS 26.5, watchOS 26.5, visionOS 26.5, *),
               error == .paymentMethodBindingConfigurationRequired {
                return .paymentMethodBindingRequired
            }

            return .unknown(error)
        }
    }

    private static func mapping(_ error: StoreKitError) -> PurchasesError {
        switch error {
        case .userCancelled:
            // The same outcome as `Product.PurchaseResult.userCancelled`; callers should not
            // have to handle cancellation twice depending on which StoreKit path reported it.
            .purchaseCancelled
        case .networkError:
            .networkUnavailable
        case .notAvailableInStorefront:
            .notAvailableInStorefront
        case .notEntitled:
            .notEntitled
        case .unsupported:
            .unsupported
        default:
            .unknown(error)
        }
    }
}

// MARK: - Equatable

// `Error` is not `Equatable`, so the conformance cannot be synthesised. Written out so
// callers and tests can compare an error against an expected case.
extension PurchasesError: Equatable {
    public static func == (lhs: PurchasesError, rhs: PurchasesError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.purchaseCancelled, .purchaseCancelled),
             (.purchasePending, .purchasePending),
             (.verificationFailed, .verificationFailed),
             (.unhandledPurchaseResult, .unhandledPurchaseResult),
             (.productUnavailable, .productUnavailable),
             (.purchaseNotAllowed, .purchaseNotAllowed),
             (.invalidQuantity, .invalidQuantity),
             (.ineligibleForOffer, .ineligibleForOffer),
             (.invalidOffer, .invalidOffer),
             (.paymentMethodBindingRequired, .paymentMethodBindingRequired),
             (.networkUnavailable, .networkUnavailable),
             (.notAvailableInStorefront, .notAvailableInStorefront),
             (.notEntitled, .notEntitled),
             (.unsupported, .unsupported):
            true
        case let (.invalidProductID(lhsID), .invalidProductID(rhsID)):
            lhsID == rhsID
        case let (.offerNotFound(lhsID), .offerNotFound(rhsID)):
            lhsID == rhsID
        case let (.unknown(lhsError), .unknown(rhsError)):
            lhsError as NSError == rhsError as NSError
        default:
            false
        }
    }
}

// MARK: - LocalizedError

// Without this, `error.localizedDescription` reports the enum's generic fallback rather than
// anything a caller can show or log. The strings are not localised: the package ships no
// resource bundle, and adding one is a larger decision than the conformance.
extension PurchasesError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "PurchasesManager.configure(identifiers:) has not been called."
        case .invalidProductID(let productID):
            "No App Store product matches the identifier “\(productID)”."
        case .purchaseCancelled:
            "The purchase was cancelled."
        case .purchasePending:
            "The purchase is pending approval and will complete later."
        case .verificationFailed:
            "The App Store transaction failed signature verification."
        case .unhandledPurchaseResult:
            "StoreKit reported a purchase result this version does not handle."
        case .productUnavailable:
            "The product is not available for purchase."
        case .purchaseNotAllowed:
            "This account is not allowed to make purchases."
        case .invalidQuantity:
            "The requested quantity is not allowed."
        case .ineligibleForOffer:
            "This account is not eligible for the requested offer."
        case .invalidOffer:
            "The requested offer is invalid or incorrectly signed."
        case .paymentMethodBindingRequired:
            "A payment method must be set up before this purchase can be made."
        case .networkUnavailable:
            "The App Store could not be reached."
        case .notAvailableInStorefront:
            "The product is not available in this account's storefront."
        case .notEntitled:
            "The app is not entitled to use this StoreKit feature."
        case .unsupported:
            "This operation is not supported on this device."
        case .offerNotFound(let offerID):
            "The product has no win-back offer with the identifier “\(offerID)”."
        case .unknown(let error):
            error.localizedDescription
        }
    }
}

//
//  RKPurchasesError.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

public import Foundation
import StoreKit

/// The error every throwing call in the SDK throws.
///
/// A struct carrying a ``Code``, the same design as Foundation's `CocoaError` and `URLError`.
/// Up to 4.0 this was an enum, and each failure StoreKit learned to report was another case —
/// a breaking change for every client with an exhaustive `switch`. With an open ``Code``, a
/// new kind of failure is a new constant, and adding one is not a breaking change. The cost is
/// that a `switch` over ``code`` needs a `default` branch.
///
/// Match a code directly in a `catch` clause, the way you would with `CocoaError`:
///
/// ```swift
/// do {
///     try await manager.purchase(productID: id)
/// } catch PurchasesError.purchaseCancelled {
///     // The customer closed the sheet; nothing to report.
/// } catch let error as PurchasesError where error.code == .networkUnavailable {
///     // Offer a retry.
/// }
/// ```
/// See <doc:PurchasesError>
public struct PurchasesError: Error, Sendable {

    // MARK: Code

    /// What went wrong, as an open set of values.
    ///
    /// A raw-value struct rather than an enum, so a code added in a later release, or a
    /// StoreKit failure that needs one, is not a breaking change. The raw values are the
    /// constants' own names; they are stable and safe to log or send to analytics.
    public struct Code: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// ``PurchasesManager/configure(identifiers:finishing:)`` has not been called.
        public static let notConfigured = Code(rawValue: "notConfigured")
        /// StoreKit returned no product for the identifier in ``PurchasesError/productID``.
        public static let invalidProductID = Code(rawValue: "invalidProductID")
        /// The customer cancelled the purchase or a StoreKit prompt.
        public static let purchaseCancelled = Code(rawValue: "purchaseCancelled")
        /// The purchase awaits approval, for example through Ask to Buy, and completes later.
        public static let purchasePending = Code(rawValue: "purchasePending")
        /// A StoreKit transaction failed signature verification.
        public static let verificationFailed = Code(rawValue: "verificationFailed")
        /// StoreKit returned a purchase result this SDK does not handle.
        ///
        /// `Product.PurchaseResult` is non-frozen, so a newer StoreKit can report an outcome
        /// that predates this build.
        public static let unhandledPurchaseResult = Code(rawValue: "unhandledPurchaseResult")
        /// The product is not available for purchase right now, for example because it was
        /// removed from sale in App Store Connect.
        public static let productUnavailable = Code(rawValue: "productUnavailable")
        /// The account is not allowed to make purchases, usually because of Screen Time or
        /// device management restrictions. Retrying will not help; explain instead.
        public static let purchaseNotAllowed = Code(rawValue: "purchaseNotAllowed")
        /// The requested quantity is outside what the App Store accepts.
        public static let invalidQuantity = Code(rawValue: "invalidQuantity")
        /// The account is not eligible for the offer that was requested.
        public static let ineligibleForOffer = Code(rawValue: "ineligibleForOffer")
        /// The offer in ``PurchaseOptions`` was rejected: unknown identifier, wrong price, bad
        /// signature or missing parameters.
        ///
        /// StoreKit reports these four separately, but every one of them means the offer was
        /// built or signed wrongly on your side, and the remedy is the same, so they share a
        /// code. The StoreKit error is kept in ``PurchasesError/underlyingError`` for logging.
        public static let invalidOffer = Code(rawValue: "invalidOffer")
        /// The App Store needs a payment method set up for this kind of purchase before it
        /// can go ahead. Reported by StoreKit from OS 26.5.
        public static let paymentMethodBindingRequired = Code(rawValue: "paymentMethodBindingRequired")
        /// The App Store could not be reached.
        ///
        /// Separate from ``unknown`` because it is the one failure worth an automatic retry
        /// or a "check your connection" message.
        public static let networkUnavailable = Code(rawValue: "networkUnavailable")
        /// The product is not sold in the account's storefront.
        public static let notAvailableInStorefront = Code(rawValue: "notAvailableInStorefront")
        /// The app is not entitled to the StoreKit feature it called, usually a missing
        /// capability or entitlement in the app's configuration.
        public static let notEntitled = Code(rawValue: "notEntitled")
        /// The device or OS does not support the requested operation.
        public static let unsupported = Code(rawValue: "unsupported")
        /// The win-back offer identifier in ``PurchaseOptions/winBackOfferID`` is not one of
        /// the product's win-back offers. The identifier is in ``PurchasesError/offerID``.
        ///
        /// Raised by the kit before StoreKit is asked, because StoreKit takes the offer itself,
        /// not its identifier, and there is nothing to pass for an identifier that matches none.
        public static let offerNotFound = Code(rawValue: "offerNotFound")
        /// A failure without a dedicated code. The original error is in
        /// ``PurchasesError/underlyingError``.
        public static let unknown = Code(rawValue: "unknown")

        /// Lets a `catch` clause match a code against the thrown error:
        /// `catch PurchasesError.purchaseCancelled { … }`.
        ///
        /// A `catch` pattern is compared with the thrown `any Error`, not with a
        /// `PurchasesError`, so this is the overload the pattern needs. Anything that is not a
        /// `PurchasesError` does not match.
        public static func ~= (code: Code, error: any Error) -> Bool {
            (error as? PurchasesError)?.code == code
        }
    }

    // MARK: Properties

    /// What went wrong.
    public let code: Code
    /// The product identifier that StoreKit did not recognise. Set for ``Code/invalidProductID``.
    public let productID: String?
    /// The win-back offer identifier the product does not have. Set for ``Code/offerNotFound``.
    public let offerID: String?
    /// The error this one was translated from.
    ///
    /// Set for ``Code/unknown`` and whenever a StoreKit error was translated into a code, so
    /// the original stays available for logging even where several StoreKit errors share one
    /// code.
    public let underlyingError: (any Error)?

    // MARK: Initial methods

    public init(
        _ code: Code,
        productID: String? = nil,
        offerID: String? = nil,
        underlyingError: (any Error)? = nil
    ) {
        self.code = code
        self.productID = productID
        self.offerID = offerID
        self.underlyingError = underlyingError
    }

    // MARK: Code shortcuts
    //
    // The same shortcuts `CocoaError` has (`CocoaError.fileNoSuchFile`): they make
    // `catch PurchasesError.purchaseCancelled` read naturally and keep 3.x catch clauses
    // compiling unchanged.

    public static var notConfigured: Code { .notConfigured }
    public static var invalidProductID: Code { .invalidProductID }
    public static var purchaseCancelled: Code { .purchaseCancelled }
    public static var purchasePending: Code { .purchasePending }
    public static var verificationFailed: Code { .verificationFailed }
    public static var unhandledPurchaseResult: Code { .unhandledPurchaseResult }
    public static var productUnavailable: Code { .productUnavailable }
    public static var purchaseNotAllowed: Code { .purchaseNotAllowed }
    public static var invalidQuantity: Code { .invalidQuantity }
    public static var ineligibleForOffer: Code { .ineligibleForOffer }
    public static var invalidOffer: Code { .invalidOffer }
    public static var paymentMethodBindingRequired: Code { .paymentMethodBindingRequired }
    public static var networkUnavailable: Code { .networkUnavailable }
    public static var notAvailableInStorefront: Code { .notAvailableInStorefront }
    public static var notEntitled: Code { .notEntitled }
    public static var unsupported: Code { .unsupported }
    public static var offerNotFound: Code { .offerNotFound }
    public static var unknown: Code { .unknown }
}

// MARK: - Mapping

extension PurchasesError {
    /// Translates an error thrown by StoreKit into the SDK's vocabulary.
    ///
    /// Callers should not need to import StoreKit and know its two error enums to tell a
    /// network failure from a disallowed purchase, so every public entry point funnels thrown
    /// errors through here. Idempotent: an error that already is a `PurchasesError` passes
    /// through unchanged, so wrapping twice on nested calls is harmless. The StoreKit error is
    /// kept as ``underlyingError``.
    static func mapping(_ error: any Error) -> PurchasesError {
        if let error = error as? PurchasesError {
            return error
        }
        if let error = error as? Product.PurchaseError {
            return PurchasesError(code(for: error), underlyingError: error)
        }
        if let error = error as? StoreKitError {
            return PurchasesError(code(for: error), underlyingError: error)
        }

        return PurchasesError(.unknown, underlyingError: error)
    }

    private static func code(for error: Product.PurchaseError) -> Code {
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

            return .unknown
        }
    }

    private static func code(for error: StoreKitError) -> Code {
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
            .unknown
        }
    }
}

// MARK: - Equatable

// `Error` is not `Equatable`, so the conformance cannot be synthesised. Written out so
// callers and tests can compare an error against an expected value. The underlying error
// takes part, compared as `NSError` (domain, code and user info), so a translated StoreKit
// error equals only the same translation; to ask "was it cancelled?", compare ``code``.
extension PurchasesError: Equatable {
    public static func == (lhs: PurchasesError, rhs: PurchasesError) -> Bool {
        guard lhs.code == rhs.code, lhs.productID == rhs.productID, lhs.offerID == rhs.offerID else {
            return false
        }

        switch (lhs.underlyingError, rhs.underlyingError) {
        case (nil, nil):
            return true
        case let (lhsError?, rhsError?):
            return lhsError as NSError == rhsError as NSError
        default:
            return false
        }
    }
}

// MARK: - LocalizedError

// Without this, `error.localizedDescription` reports Foundation's generic fallback rather than
// anything a caller can show or log. The strings are not localised: the package ships no
// resource bundle, and adding one is a larger decision than the conformance.
extension PurchasesError: LocalizedError {
    public var errorDescription: String? {
        switch code {
        case .notConfigured:
            return "PurchasesManager.configure(identifiers:) has not been called."
        case .invalidProductID:
            guard let productID else {
                return "No App Store product matches the requested identifier."
            }
            return "No App Store product matches the identifier “\(productID)”."
        case .purchaseCancelled:
            return "The purchase was cancelled."
        case .purchasePending:
            return "The purchase is pending approval and will complete later."
        case .verificationFailed:
            return "The App Store transaction failed signature verification."
        case .unhandledPurchaseResult:
            return "StoreKit reported a purchase result this version does not handle."
        case .productUnavailable:
            return "The product is not available for purchase."
        case .purchaseNotAllowed:
            return "This account is not allowed to make purchases."
        case .invalidQuantity:
            return "The requested quantity is not allowed."
        case .ineligibleForOffer:
            return "This account is not eligible for the requested offer."
        case .invalidOffer:
            return "The requested offer is invalid or incorrectly signed."
        case .paymentMethodBindingRequired:
            return "A payment method must be set up before this purchase can be made."
        case .networkUnavailable:
            return "The App Store could not be reached."
        case .notAvailableInStorefront:
            return "The product is not available in this account's storefront."
        case .notEntitled:
            return "The app is not entitled to use this StoreKit feature."
        case .unsupported:
            return "This operation is not supported on this device."
        case .offerNotFound:
            guard let offerID else {
                return "The product has no win-back offer with the requested identifier."
            }
            return "The product has no win-back offer with the identifier “\(offerID)”."
        case .unknown:
            // The wrapped error knows more about itself than the kit does.
            return underlyingError?.localizedDescription ?? "An unknown purchase error occurred."
        default:
            // A code this build has no wording for, made by a caller or a later release.
            return underlyingError?.localizedDescription
                ?? "The purchase failed with the error “\(code.rawValue)”."
        }
    }
}

//
//  RKPurchasesError.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

/// All error cases thrown by the SDK.
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
    case unknown(Error)
}

// `Error` is not `Equatable`, so the conformance cannot be synthesised. Written out so
// callers and tests can compare an error against an expected case.
extension PurchasesError: Equatable {
    public static func == (lhs: PurchasesError, rhs: PurchasesError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.purchaseCancelled, .purchaseCancelled),
             (.purchasePending, .purchasePending),
             (.verificationFailed, .verificationFailed),
             (.unhandledPurchaseResult, .unhandledPurchaseResult):
            true
        case let (.invalidProductID(lhsID), .invalidProductID(rhsID)):
            lhsID == rhsID
        case let (.unknown(lhsError), .unknown(rhsError)):
            lhsError as NSError == rhsError as NSError
        default:
            false
        }
    }
}

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
        case .unknown(let error):
            error.localizedDescription
        }
    }
}

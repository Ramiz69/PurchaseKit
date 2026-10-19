//
//  RKRefundRequestStatus.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

import StoreKit

/// What the customer did with the refund request sheet.
///
/// `success` means the request was submitted, not that a refund was granted: Apple decides
/// later, and a granted refund arrives as a revoked transaction through the update stream.
///
/// A raw-value struct rather than an enum, so an outcome StoreKit adds later does not break an
/// exhaustive `switch`. `Transaction.RefundRequestStatus` exists on every platform the kit
/// supports, so this type does too, even where no refund sheet can be shown.
public struct RefundRequestStatus: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The customer submitted the request.
    public static let success = RefundRequestStatus(rawValue: "success")
    /// The customer dismissed the sheet without submitting.
    public static let userCancelled = RefundRequestStatus(rawValue: "userCancelled")

    init(_ status: Transaction.RefundRequestStatus) {
        switch status {
        case .success:
            self = .success
        case .userCancelled:
            self = .userCancelled
        @unknown default:
            // StoreKit's enum has no raw value; its description is the most faithful name
            // available for an outcome this build has never seen.
            self.init(rawValue: String(describing: status))
        }
    }
}

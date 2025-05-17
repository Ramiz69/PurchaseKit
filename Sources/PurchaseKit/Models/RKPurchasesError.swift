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
    case unknown(Error)
}

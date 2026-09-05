//
//  RKProductType.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

/// Maps ``StoreKit.Product.ProductType`` into an SDK-level enum.
/// - See <doc:ProductType>
public enum ProductType: Sendable {
    case nonConsumable
    case consumable
    case nonRenewable
    case autoRenewable
    /// A `StoreKit.Product.ProductType` this SDK does not know.
    ///
    /// `Product.ProductType` is a non-frozen raw-value type, so a StoreKit release can add a
    /// kind that predates the SDK build. Such a product used to arrive as `nonConsumable`,
    /// which reads as a permanent one-off purchase — the wrong answer to act on, and silent
    /// about being a guess. Treat this case as "do not assume anything about entitlement".
    case unknown

    init(_ productType: Product.ProductType) {
        switch productType {
        case .nonConsumable:
            self = .nonConsumable
        case .consumable:
            self = .consumable
        case .nonRenewable:
            self = .nonRenewable
        case .autoRenewable:
            self = .autoRenewable
        default:
            self = .unknown
        }
    }
}

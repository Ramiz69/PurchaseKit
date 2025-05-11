//
//  RKPurchasedProductEvent.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

/// Event emitted through ``PurchasesManager/purchasedProducts``.
/// - See <doc:PurchasedProductEvent>
public struct PurchasedProductEvent: Sendable {
    public let product: StoreProduct
}

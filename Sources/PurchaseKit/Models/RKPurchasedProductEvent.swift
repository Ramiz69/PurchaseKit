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

    /// Creates an event.
    ///
    /// The memberwise initializer a struct gets for free is internal, so mock
    /// implementations of ``PurchasesProtocol`` could not build one of these to feed a
    /// stand-in event stream. This one is public for that purpose.
    public init(product: StoreProduct) {
        self.product = product
    }
}

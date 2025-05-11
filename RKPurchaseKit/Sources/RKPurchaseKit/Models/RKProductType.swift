//
//  RKProductType.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

public enum ProductType: Sendable {
    case nonConsumable
    case consumable
    case nonRenewable
    case autoRenewable

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
            self = .nonConsumable
        }
    }
}

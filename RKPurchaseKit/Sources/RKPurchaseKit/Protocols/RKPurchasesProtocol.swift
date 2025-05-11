//
//  RKPurchasesProtocol.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

public protocol PurchasesProtocol: Sendable {
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> StoreProduct
    func restore() async throws
}

public extension PurchasesProtocol {
    func requestProducts(includingCache: Bool = true) async throws -> [StoreProduct] {
        []
    }
}

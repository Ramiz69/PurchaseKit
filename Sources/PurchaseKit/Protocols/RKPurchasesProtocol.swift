//
//  RKPurchasesProtocol.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

/// Protocol abstraction to allow mocking in tests.
/// Full spec: <doc:PurchasesProtocol>
public protocol PurchasesProtocol: Sendable {
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> StoreProduct
    func restore() async throws
}

/// Default wrapper that keeps source compatibility.
/// - SeeAlso: ``PurchasesProtocol/requestProducts(includingCache:)``
public extension PurchasesProtocol {
    func requestProducts(includingCache: Bool = true) async throws -> [StoreProduct] {
        []
    }
}

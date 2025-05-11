//
//  RKPurchasesManager.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import StoreKit

public actor PurchasesManager: PurchasesProtocol {

    // MARK: Properties

    public nonisolated static var shared: PurchasesManager {
        guard let instance else {
            fatalError("❗️ PurchasesActor.configure(identifiers:) must be called before first use.")
        }

        return instance
    }
    public static var isolated: PurchasesManager {
        get async throws {
            guard let instance else { throw PurchasesError.notConfigured }

            return instance
        }
    }
    public nonisolated let purchasedProducts: AsyncStream<PurchasedProductEvent>
    private let identifiers: [String]
    private var productsCache: [String: StoreProduct] = [:]
    private let continuation: AsyncStream<PurchasedProductEvent>.Continuation
    private var updateListenerTask: Task<Void, Never>?
    private static var instance: PurchasesManager?

    // MARK: Initial methods

    private init(identifiers: [String]) {
        self.identifiers = identifiers
        let pair = AsyncStream.makeStream(of: PurchasedProductEvent.self)
        self.purchasedProducts = pair.stream
        self.continuation = pair.continuation
    }

    deinit {
        updateListenerTask?.cancel()
        continuation.finish()
    }

    // MARK: Public methods

    @discardableResult
    public nonisolated static func configure(identifiers: [String]) -> PurchasesManager {
        precondition(instance == nil, "PurchasesActor.configure(_:)" + " has already been called. Double configuration is not allowed.")
        let instance = PurchasesManager(identifiers: identifiers)
        self.instance = instance
        Task.detached {
            await instance.startListener()
        }

        return instance
    }

    public func requestProducts(includingCache: Bool) async throws -> [StoreProduct] {
        if includingCache {
            let cachedProducts = productsCache.values.map { $0 }
            if !cachedProducts.isEmpty {
                return cachedProducts
            }
        }
        let storeProducts = try await Product.products(for: identifiers)
        for product in storeProducts {
            cache(product)
        }
        await updateCustomerProductStatus()

        return productsCache.values.map { $0 }
    }

    public func purchase(productID: String) async throws -> StoreProduct {
        guard let product = try await Product.products(for: [productID]).first else {
            throw PurchasesError.invalidProductID(productID)
        }

        switch try await product.purchase() {
        case .success(let result):
            let transaction = try checkVerified(result)
            await transaction.finish()
            cache(product)
            try await markPurchased(productID: product.id)

            return productsCache[product.id]!
        case .userCancelled:
            throw PurchasesError.purchaseCancelled
        case .pending:
            throw PurchasesError.purchasePending
        default:
            throw PurchasesError.unknown(PurchasesError.unknown(NSError(domain: "unknown", code: -1)))
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
    }

    // MARK: Private methods

    private func startListener() async {
        guard updateListenerTask == nil else { return }

        updateListenerTask = Task { await listenForTransactions() }
    }

    private func cache(_ product: Product, purchased: Bool = false) {
        productsCache[product.id] = map(product, purchased)
    }

    private func map(_ product: Product, _ isPurchased: Bool) -> StoreProduct {
        StoreProduct(
            productID: product.id,
            type: ProductType(product.type),
            displayName: product.displayName,
            description: product.description,
            price: product.price,
            displayPrice: product.displayPrice,
            isFamilyShareable: product.isFamilyShareable,
            isPurchased: isPurchased
        )
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signed): signed
        case .unverified: throw PurchasesError.verificationFailed
        }
    }

    private func markPurchased(productID: String) async throws {
        guard let cached = productsCache[productID] else { return }

        let updated = cached.setPurchasingFlag(true)
        productsCache[productID] = updated
        continuation.yield(PurchasedProductEvent(product: updated))
    }

    private func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            guard
                let transaction = try? checkVerified(result),
                let products = try? await Product.products(for: [transaction.productID]),
                let product = products.first
            else {
                continue
            }

            try? await markPurchased(productID: product.id)
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }

            try? await markPurchased(productID: transaction.productID)
            await transaction.finish()
        }
    }
}

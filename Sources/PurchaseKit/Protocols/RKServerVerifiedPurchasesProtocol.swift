//
//  RKServerVerifiedPurchasesProtocol.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 09.10.2026.
//

public import Foundation
#if os(visionOS)
public import UIKit
#endif

/// The purchase flow for apps whose server, not the device, decides what a purchase is worth.
///
/// Typical for consumables credited to an account: the app buys with an
/// `appAccountToken` that ties the transaction to the signed-in user, sends the signed
/// transaction to its server, and finishes it only after the server has credited it.
/// Configure the manager with ``FinishPolicy/manual`` for this flow.
///
/// A separate protocol rather than new requirements on ``PurchasesProtocol``: adding
/// requirements there would break every existing conformer, including the stand-ins apps
/// write for tests and previews. ``PurchasesManager`` conforms to both.
public protocol ServerVerifiedPurchasesProtocol: PurchasesProtocol {
    /// Every verified transaction StoreKit delivers outside a purchase call: a purchase
    /// approved later (Ask to Buy, a pending payment), one made on another device, and
    /// the unfinished ones replayed on launch.
    ///
    /// Each access returns a fresh stream; events are not replayed. A transaction that is
    /// missed here stays unfinished under ``FinishPolicy/manual`` - read it back with
    /// ``unfinishedTransactions()``.
    var transactionUpdates: AsyncStream<StoreTransaction> { get }

    #if !os(visionOS)
    /// Buys `productID` on behalf of the account identified by `appAccountToken`.
    ///
    /// The token travels inside the signed transaction, so the server can check that the
    /// purchase belongs to the account it is about to credit.
    func purchase(
        productID: String,
        appAccountToken: UUID?
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction)
    #endif

    #if os(visionOS)
    /// Buys `productID` on behalf of the account identified by `appAccountToken`,
    /// presenting the App Store confirmation in `scene`.
    @MainActor
    func purchase(
        productID: String,
        appAccountToken: UUID?,
        confirmIn scene: UIScene
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction)
    #endif

    /// Finishes `transaction`, telling the App Store it has been delivered.
    ///
    /// Call after the server has accepted the transaction. Finishing one that is already
    /// finished does nothing.
    func finish(_ transaction: StoreTransaction) async

    /// Verified transactions StoreKit still holds as unfinished.
    ///
    /// Read at launch and after sign-in to forward whatever a previous run did not manage to
    /// deliver to the server.
    func unfinishedTransactions() async -> [StoreTransaction]
}

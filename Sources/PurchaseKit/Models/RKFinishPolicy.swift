//
//  RKFinishPolicy.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 09.10.2026.
//

/// Who finishes a StoreKit transaction, and when.
///
/// Finishing tells the App Store that the app has delivered what was bought. For a
/// consumable that is the end of the road: a finished consumable is gone from
/// `Transaction.unfinished` and is never redelivered. If the app finishes it before its own
/// server has credited the purchase, and the request to that server is then lost, the
/// customer has paid for something that nobody will ever hand over.
///
/// Set once, in ``PurchasesManager/configure(identifiers:finishing:)``.
public enum FinishPolicy: Sendable, Equatable {
    /// The kit finishes every verified transaction as soon as it sees it: after a purchase
    /// and for every `Transaction.updates` delivery. Right for apps that unlock content on
    /// the device. This is the default and the behaviour of every release before 3.2.
    case automatic
    /// The kit never finishes a transaction. The app forwards it to its server - usually
    /// ``StoreTransaction/jwsRepresentation`` - and calls
    /// ``PurchasesManager/finish(_:)`` only once the server has accepted it.
    ///
    /// Until then StoreKit keeps the transaction in `Transaction.unfinished` and redelivers
    /// it through ``PurchasesManager/transactionUpdates`` on the next launch, so a crash or a
    /// lost response costs a retry instead of a purchase.
    case manual
}

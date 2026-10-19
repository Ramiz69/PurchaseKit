//
//  RKPurchasesManager+StoreSheets.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 19.10.2026.
//

// StoreKit offers these sheets only where an app has a `UIWindowScene`: iOS, Mac Catalyst
// (where `os(iOS)` holds) and visionOS. macOS has view-controller-based variants with a
// different shape, and watchOS and tvOS have none, so the helpers are not declared there
// rather than declared to fail.
#if os(iOS) || os(visionOS)
import StoreKit
public import UIKit

/// Wrappers around StoreKit's scene-based App Store sheets.
///
/// Manager-only, not ``PurchasesProtocol`` requirements: they present system UI and decide
/// nothing a stand-in would need to fake. Each runs on the main actor because StoreKit
/// presents in `scene`, and translates StoreKit's errors into ``PurchasesError`` like every
/// other throwing call.
extension PurchasesManager {

    // MARK: Public methods

    /// Shows the system's manage-subscriptions sheet.
    ///
    /// - Parameters:
    ///   - scene: The window scene that presents the sheet.
    ///   - groupID: A subscription group to focus the sheet on, or `nil` for all of the
    ///     customer's subscriptions to this app.
    /// - Throws: ``PurchasesError``; StoreKit's own errors are translated into its cases.
    @MainActor
    public func showManageSubscriptions(in scene: UIWindowScene, groupID: String? = nil) async throws {
        do {
            if let groupID {
                try await AppStore.showManageSubscriptions(in: scene, subscriptionGroupID: groupID)
            } else {
                try await AppStore.showManageSubscriptions(in: scene)
            }
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
    /// Shows the refund request sheet for a transaction.
    ///
    /// The result says what the customer did with the sheet, not whether Apple grants the
    /// refund. A granted refund arrives later as a revoked transaction, which the transaction
    /// listener applies to the entitlement state on its own.
    ///
    /// - Parameters:
    ///   - transactionID: ``StoreTransaction/id`` of the purchase to refund.
    ///   - scene: The window scene that presents the sheet.
    /// - Returns: Whether the customer submitted the request.
    /// - Throws: ``PurchasesError``; StoreKit's own errors are translated into its cases.
    @MainActor
    public func beginRefundRequest(for transactionID: UInt64, in scene: UIWindowScene) async throws -> RefundRequestStatus {
        do {
            return RefundRequestStatus(try await Transaction.beginRefundRequest(for: transactionID, in: scene))
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
    /// Shows the sheet for redeeming an offer code.
    ///
    /// A redeemed code produces a transaction that arrives through the transaction listener,
    /// not as a return value, so ``purchasedProducts`` and ``transactionUpdates`` report it
    /// like a purchase made on another device.
    ///
    /// - Parameter scene: The window scene that presents the sheet.
    /// - Throws: ``PurchasesError``; StoreKit's own errors are translated into its cases.
    @MainActor
    public func presentOfferCodeRedeemSheet(in scene: UIWindowScene) async throws {
        do {
            // The scene variant is deprecated from OS 27 in favour of one that returns the
            // transaction, but its replacement does not exist in the OS 26 SDK this kit still
            // builds with, and the deployment target keeps the deprecation silent.
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
        } catch {
            throw PurchasesError.mapping(error)
        }
    }
}
#endif

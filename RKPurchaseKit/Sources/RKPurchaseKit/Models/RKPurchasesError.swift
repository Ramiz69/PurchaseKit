//
//  RKPurchasesError.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

public enum PurchasesError: Error, Sendable {
    case notConfigured
    case invalidProductID(String)
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case unknown(Error)
}

//
//  PaywallDemoApp.swift
//  PaywallDemo
//

import RKPurchaseKit
import SwiftUI

@main
struct PaywallDemoApp: App {
    init() {
        // Configure once, as early as possible. Besides naming the products, this starts the
        // kit's transaction listener: purchases approved while the app was closed (Ask to
        // Buy, renewals, purchases on another device) are delivered as soon as it launches.
        // Calling it twice is a programmer error and traps.
        PurchasesManager.configure(identifiers: Catalog.all)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

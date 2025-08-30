# RKPurchaseKit

@Metadata {
    @DisplayName("PurchaseKit")
    @SupportedLanguage(swift)
    @Available(iOS, introduced: "15.0")
    @Available(tvOS, introduced: "15.0")
    @Available(macOS, introduced: "12.0")
    @Available(macCatalyst, introduced: "15.0")
    @Available(watchOS, introduced: "8.0")
    @Available(visionOS, introduced: "1.0")
    @PageColor(green)
}

`RKPurchaseKit` is a lightweight, actor-based convenience layer on top of **StoreKit 2**.

## Features

- Actor-based, Swift Concurrency–first API
- Product caching with instant repeat calls
- Purchase & restore flows with typed errors
- Live transaction listening via `AsyncStream`
- **Entitlement helpers**:
  - ``PurchasesManager/hasEntitlement(for:)``
  - ``PurchasesManager/entitlementProductIDs()``
  - ``PurchasesManager/activeSubscriptions()``
  - ``PurchasesManager/activeSubscription(inGroup:)``
- Simple value model: ``StoreProduct`` (with ``StoreProduct/subscriptionGroupID``)

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:PurchasesManager>
    - <doc:PurchasesProtocol>
    - <doc:StoreProduct>
    - <doc:PurchasesError>
    - <doc:PurchasedProductEvent>
    - <doc:ProductType>
}

## Requirements

- Swift 6, StoreKit 2
- iOS 15.0 / macOS 12.0 / tvOS 15.0 / watchOS 8.0 / visionOS 1.0+

## Notes

- Entitlement state is derived from `Transaction.currentEntitlements` and reflected in ``StoreProduct/isPurchased``.
- The manager refreshes entitlements after fetching products and after ``PurchasesManager/restore()``.
- When you update UI from callbacks or streams, hop to `MainActor`.

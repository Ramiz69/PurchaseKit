# ``StoreProduct``

Value type describing a product, enriched with a few convenience fields for UI and entitlement state.

Normally the kit builds these for you from `StoreKit.Product`, and ``StoreProduct/product`` carries the product it was read from. You can also build one directly with the public initializer, for tests, SwiftUI previews and mock implementations of ``PurchasesProtocol``; ``StoreProduct/product`` is `nil` on those, because `StoreKit.Product` has no public initializer and cannot be created outside StoreKit.

## Properties

- ``StoreProduct/product`` – the backing `StoreKit.Product`, `nil` when the value was not read from StoreKit
- ``StoreProduct/productID``
- ``StoreProduct/type``
- ``StoreProduct/displayName``
- ``StoreProduct/price``
- ``StoreProduct/displayPrice``
- ``StoreProduct/isPurchased``
- ``StoreProduct/subscriptionGroupID``

> Tip: For auto-renewable subscriptions, `subscriptionGroupID` helps you select the “best” active subscription within a group (see ``PurchasesManager/activeSubscription(inGroup:)``).

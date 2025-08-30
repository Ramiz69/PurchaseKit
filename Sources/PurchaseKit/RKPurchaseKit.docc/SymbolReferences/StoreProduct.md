# ``StoreProduct``

Value-type wrapper around `StoreKit.Product`, enriched with a few convenience fields for UI and entitlement state.

## Properties

- ``StoreProduct/productID``
- ``StoreProduct/type``
- ``StoreProduct/displayName``
- ``StoreProduct/price``
- ``StoreProduct/displayPrice``
- ``StoreProduct/isPurchased``
- ``StoreProduct/subscriptionGroupID``

Use ``StoreProduct/setPurchasingFlag(_:)`` to create a copy with an updated purchase state.

> Tip: For auto-renewable subscriptions, `subscriptionGroupID` helps you select the “best” active subscription within a group (see ``PurchasesManager/activeSubscription(inGroup:)``).

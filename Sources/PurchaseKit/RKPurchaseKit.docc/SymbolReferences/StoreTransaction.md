# ``StoreTransaction``

Value type describing a completed transaction.

Normally the kit builds these for you from `StoreKit.Transaction`, and ``StoreTransaction/transaction`` carries the transaction it was read from. You can also build one directly, which `StoreKit.Transaction` does not allow — it has no public initializer — and that is what makes ``PurchasesProtocol/purchase(productID:)`` mockable: a stand-in can return a successful purchase instead of only being able to throw. ``StoreTransaction/transaction`` is `nil` on such a value.

## Properties

- ``StoreTransaction/transaction`` – the backing `StoreKit.Transaction`, `nil` when the value was not read from StoreKit
- ``StoreTransaction/id`` / ``StoreTransaction/originalID``
- ``StoreTransaction/productID``
- ``StoreTransaction/purchaseDate`` / ``StoreTransaction/originalPurchaseDate``
- ``StoreTransaction/expirationDate`` – auto-renewable subscriptions only
- ``StoreTransaction/revocationDate`` – non-`nil` once refunded or revoked, meaning the entitlement is gone
- ``StoreTransaction/isUpgraded``
- ``StoreTransaction/purchasedQuantity``
- ``StoreTransaction/appAccountToken``
- ``StoreTransaction/subscriptionGroupID``

> Tip: When only `id` and `productID` matter, the identity fields default sensibly — `originalID` falls back to `id` and `originalPurchaseDate` to `purchaseDate`.

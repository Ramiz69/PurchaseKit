# ``StoreTransaction``

Value type describing a completed transaction.

Normally the kit builds these for you from `StoreKit.Transaction`, and ``StoreTransaction/transaction`` carries the transaction it was read from. You can also build one directly, which `StoreKit.Transaction` does not allow — it has no public initializer — and that is what makes ``PurchasesProtocol/purchase(productID:options:)`` mockable: a stand-in can return a successful purchase instead of only being able to throw. ``StoreTransaction/transaction`` is `nil` on such a value.

## Properties

- ``StoreTransaction/transaction`` – the backing `StoreKit.Transaction`, `nil` when the value was not read from StoreKit
- ``StoreTransaction/id`` / ``StoreTransaction/originalID``
- ``StoreTransaction/productID``
- ``StoreTransaction/productType``
- ``StoreTransaction/purchaseDate`` / ``StoreTransaction/originalPurchaseDate``
- ``StoreTransaction/expirationDate`` – auto-renewable subscriptions only
- ``StoreTransaction/revocationDate`` – non-`nil` once refunded or revoked, meaning the entitlement is gone
- ``StoreTransaction/revocationReason`` / ``StoreTransaction/revocationType`` – why and how it was revoked
- ``StoreTransaction/isUpgraded``
- ``StoreTransaction/purchasedQuantity``
- ``StoreTransaction/appAccountToken``
- ``StoreTransaction/subscriptionGroupID``
- ``StoreTransaction/ownershipType`` / ``StoreTransaction/isFamilyShared`` – bought by this account, or shared by a family member
- ``StoreTransaction/environment`` – production, sandbox or Xcode
- ``StoreTransaction/reason`` – a purchase or a renewal
- ``StoreTransaction/offer`` – the offer applied to this transaction, if any
- ``StoreTransaction/billingPlanType`` – how the customer pays for the subscription
- ``StoreTransaction/storefrontCountryCode``
- ``StoreTransaction/price`` / ``StoreTransaction/currencyCode`` – what the customer actually paid
- ``StoreTransaction/jwsRepresentation`` – the App Store's signed form, for your server to verify

> Tip: When only `id` and `productID` matter, the identity fields default sensibly — `originalID` falls back to `id` and `originalPurchaseDate` to `purchaseDate`. Every field added in 4.0 has a default too.

`revocationType` and `billingPlanType` come from StoreKit APIs added in OS 26.4. On earlier
26.x systems they are `nil`.

## Open-ended kinds

``StoreTransaction/OwnershipType``, ``StoreEnvironment``, ``StoreTransaction/Reason``,
``StoreTransaction/RevocationReason``, ``StoreTransaction/RevocationType`` and
``StoreTransaction/BillingPlanType`` are `RawRepresentable` structs with static values, the
same shape StoreKit uses. A value a future StoreKit introduces is still representable, so
adding one is not a breaking change. Compare with `==` rather than `switch` exhaustively:

```swift
if transaction.environment == .sandbox {
    log("Sandbox purchase:", transaction.productID)
}
```

## Topics

### Nested types

- ``StoreTransaction/Offer``
- ``StoreTransaction/OwnershipType``
- ``StoreTransaction/Reason``
- ``StoreTransaction/RevocationReason``
- ``StoreTransaction/RevocationType``
- ``StoreTransaction/BillingPlanType``

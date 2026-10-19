# ``PurchaseOptions``

Everything about a purchase besides the product: whose account it is for, how many, and which
offer applies.

## Overview

Pass options to ``PurchasesProtocol/purchase(productID:options:)``. Every field has a default,
and ``PurchaseOptions/none`` is a purchase with none of them set.

```swift
let options = PurchaseOptions(
    appAccountToken: user.id,
    quantity: 3
)
let (_, transaction) = try await PurchasesManager.shared
    .purchase(productID: "com.myapp.coins.100", options: options)
```

- ``appAccountToken`` – ties the transaction to an account in your system; it is signed into
  ``StoreTransaction/jwsRepresentation``.
- ``quantity`` – units of a consumable, `1` by default.
- ``promotionalOffer`` – an offer ID and the compact JWS your server signed for it.
- ``winBackOfferID`` – the ``SubscriptionOffer/id`` of one of the product's
  ``StoreProduct/winBackOffers``. An ID the product does not have throws
  ``PurchasesError/offerNotFound(_:)`` before the purchase sheet appears.
- ``introductoryOfferEligibilityJWS`` – a server-signed decision on whether this customer gets
  the introductory offer, overriding the App Store's own check.
- ``simulatesAskToBuyInSandbox`` – makes a sandbox purchase go through Ask to Buy, so you can
  test ``PurchasesError/purchasePending`` and the later approval.

Signed values are produced on your server with your In-App Purchase key, never in the app:
the key must not ship in the binary. See <doc:Subscriptions>.

## Topics

### Creating options
- ``init(appAccountToken:quantity:promotionalOffer:winBackOfferID:introductoryOfferEligibilityJWS:simulatesAskToBuyInSandbox:)``
- ``none``

### Account
- ``appAccountToken``

### Quantity
- ``quantity``

### Offers
- ``promotionalOffer``
- ``PromotionalOffer``
- ``winBackOfferID``
- ``introductoryOfferEligibilityJWS``

### Testing
- ``simulatesAskToBuyInSandbox``

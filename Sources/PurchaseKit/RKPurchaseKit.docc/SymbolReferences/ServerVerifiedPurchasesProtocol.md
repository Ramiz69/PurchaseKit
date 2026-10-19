# ``ServerVerifiedPurchasesProtocol``

The purchase flow for apps whose server credits purchases to an account.

Buy with an `appAccountToken`, send ``StoreTransaction/jwsRepresentation`` to your server, and
call ``finish(_:)`` only after the server has accepted it. Configure ``PurchasesManager`` with
``FinishPolicy/manual`` so the kit never finishes a transaction on its own.

It is a separate protocol so that ``PurchasesProtocol`` conformers that do not need this flow
are not asked to implement it. ``PurchasesManager`` conforms to both.

## Overview

The account token is one of the ``PurchaseOptions``, so the purchase itself goes through
``PurchasesProtocol/purchase(productID:options:)``.
``purchase(productID:appAccountToken:)`` is a convenience that builds the options for you:

```swift
let (_, transaction) = try await PurchasesManager.shared
    .purchase(productID: "com.myapp.coins.100", appAccountToken: user.id)

// Same call, spelled out:
let (_, sameTransaction) = try await PurchasesManager.shared
    .purchase(productID: "com.myapp.coins.100", options: PurchaseOptions(appAccountToken: user.id))
```

A mock implements ``transactionUpdates``, ``finish(_:)`` and ``unfinishedTransactions()`` on
top of the ``PurchasesProtocol`` requirements. It no longer implements
`purchase(productID:appAccountToken:)`; record the token from the `options` it receives instead.

On visionOS the convenience is `purchase(productID:appAccountToken:confirmIn:)`.

## Topics

### Purchasing
- ``purchase(productID:appAccountToken:)``

### Delivering
- ``finish(_:)``
- ``unfinishedTransactions()``
- ``transactionUpdates``

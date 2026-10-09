# ``ServerVerifiedPurchasesProtocol``

The purchase flow for apps whose server credits purchases to an account.

Buy with an `appAccountToken`, send ``StoreTransaction/jwsRepresentation`` to your server, and
call ``finish(_:)`` only after the server has accepted it. Configure ``PurchasesManager`` with
``FinishPolicy/manual`` so the kit never finishes a transaction on its own.

It is a separate protocol so that existing ``PurchasesProtocol`` conformers - including the
stand-ins written for tests - keep compiling. ``PurchasesManager`` conforms to both.

## Topics

### Purchasing
- ``purchase(productID:appAccountToken:)``

### Delivering
- ``finish(_:)``
- ``unfinishedTransactions()``
- ``transactionUpdates``

# ``PurchasesError``

`enum` representing all error conditions that can be thrown by **RKPurchaseKit**.

## Overview

- ``PurchasesError/notConfigured`` – `configure(identifiers:)` hasn’t been called.
- ``PurchasesError/invalidProductID(_:)`` – StoreKit returned no `Product` for the given ID.
- ``PurchasesError/purchaseCancelled`` – the user explicitly cancelled the transaction.
- ``PurchasesError/purchasePending`` – the transaction is pending external action (e.g. Ask-to-Buy).
- ``PurchasesError/unhandledPurchaseResult`` – StoreKit reported a purchase result newer than this SDK build.
- ``PurchasesError/verificationFailed`` – StoreKit 2 signature could not be verified.
- ``PurchasesError/unknown(_:)`` – wrapper for any unexpected `Error`. Its description is the wrapped error's.

The type conforms to `Equatable`, so a caller can compare a thrown error against an expected case, and to `LocalizedError`, so `localizedDescription` carries usable text.

## Topics

### Configuration Errors

- ``PurchasesError/notConfigured``

### Product Lookup

- ``PurchasesError/invalidProductID(_:)``

### Purchase Flow

- ``PurchasesError/purchaseCancelled``
- ``PurchasesError/purchasePending``
- ``PurchasesError/unhandledPurchaseResult``

### Verification

- ``PurchasesError/verificationFailed``

### Other

- ``PurchasesError/unknown(_:)``

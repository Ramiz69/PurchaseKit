# ``PurchasesError``

`enum` representing all error conditions that can be thrown by **RKPurchaseKit**.

## Topics

### Configuration Errors
* ``PurchasesError/notConfigured`` – `configure(identifiers:)` hasn’t been called.

### Product Lookup
* ``PurchasesError/invalidProductID(_:)`` – StoreKit returned no `Product` for the given ID.

### Purchase Flow
* ``PurchasesError/purchaseCancelled`` – the user explicitly cancelled the transaction.  
* ``PurchasesError/purchasePending`` – the transaction is pending external action (e.g. Ask-to-Buy).
* ``PurchasesError/unhandledPurchaseResult`` – StoreKit reported a purchase result newer than this SDK build.

### Verification
* ``PurchasesError/verificationFailed`` – StoreKit 2 signature could not be verified.

### Other
* ``PurchasesError/unknown(_:)`` – wrapper for any unexpected `Error`. Its description is the wrapped error's.

The type conforms to `Equatable`, so a caller can compare a thrown error against an expected case, and to `LocalizedError`, so `localizedDescription` carries usable text.

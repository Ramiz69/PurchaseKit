# ``PurchasesError``

`enum` representing all error conditions that can be thrown by **RKPurchaseKit**.

## Overview

Every throwing call on ``PurchasesManager`` throws a `PurchasesError`. StoreKit's own errors
(`StoreKitError`, `Product.PurchaseError`) are translated into the matching case below, so a
caller can handle each failure without importing StoreKit's error types. Anything without a
dedicated case is wrapped in ``PurchasesError/unknown(_:)``.

- ``PurchasesError/notConfigured`` – `configure(identifiers:)` hasn’t been called.
- ``PurchasesError/invalidProductID(_:)`` – StoreKit returned no `Product` for the given ID.
- ``PurchasesError/purchaseCancelled`` – the user explicitly cancelled the transaction.
- ``PurchasesError/purchasePending`` – the transaction is pending external action (e.g. Ask-to-Buy).
- ``PurchasesError/unhandledPurchaseResult`` – StoreKit reported a purchase result newer than this SDK build.
- ``PurchasesError/productUnavailable`` – the product exists but cannot be bought right now.
- ``PurchasesError/purchaseNotAllowed`` – purchases are disabled on this device, for example by Screen Time.
- ``PurchasesError/invalidQuantity`` – ``PurchaseOptions/quantity`` is out of the allowed range.
- ``PurchasesError/ineligibleForOffer`` – the customer is not eligible for the requested offer.
- ``PurchasesError/invalidOffer`` – the offer ID, price, signature or parameters were rejected.
- ``PurchasesError/offerNotFound(_:)`` – the win-back offer ID in ``PurchaseOptions`` is not on the product.
- ``PurchasesError/paymentMethodBindingRequired`` – the App Store needs the customer to set up a payment method first.
- ``PurchasesError/networkUnavailable`` – the App Store could not be reached.
- ``PurchasesError/notAvailableInStorefront`` – the product is not sold in the customer's storefront.
- ``PurchasesError/notEntitled`` – the app is not entitled to the requested StoreKit feature.
- ``PurchasesError/unsupported`` – the operation is not supported on this platform or configuration.
- ``PurchasesError/verificationFailed`` – StoreKit 2 signature could not be verified.
- ``PurchasesError/unknown(_:)`` – wrapper for any unexpected `Error`. Its description is the wrapped error's.

`StoreKitError.userCancelled` is reported as ``PurchasesError/purchaseCancelled``, the same as
a cancelled purchase sheet, so one `catch` covers both.

The type conforms to `Equatable`, so a caller can compare a thrown error against an expected case, and to `LocalizedError`, so `localizedDescription` carries usable text.

```swift
do {
    _ = try await PurchasesManager.shared.purchase(productID: "com.myapp.pro")
} catch PurchasesError.purchaseCancelled {
    // No error UI needed.
} catch PurchasesError.networkUnavailable {
    showOfflineBanner()
} catch {
    showAlert(error.localizedDescription)
}
```

`PurchasesError` stays an `enum` so that callers can `switch` over it. Adding a case is
therefore a source-breaking change for exhaustive switches; 4.0 added eleven. A `default`
branch keeps a switch compiling across releases. See <doc:MigratingTo4>.

## Topics

### Configuration Errors

- ``PurchasesError/notConfigured``

### Product Lookup

- ``PurchasesError/invalidProductID(_:)``
- ``PurchasesError/productUnavailable``
- ``PurchasesError/notAvailableInStorefront``

### Purchase Flow

- ``PurchasesError/purchaseCancelled``
- ``PurchasesError/purchasePending``
- ``PurchasesError/purchaseNotAllowed``
- ``PurchasesError/invalidQuantity``
- ``PurchasesError/paymentMethodBindingRequired``
- ``PurchasesError/unhandledPurchaseResult``

### Offers

- ``PurchasesError/ineligibleForOffer``
- ``PurchasesError/invalidOffer``
- ``PurchasesError/offerNotFound(_:)``

### Environment

- ``PurchasesError/networkUnavailable``
- ``PurchasesError/notEntitled``
- ``PurchasesError/unsupported``

### Verification

- ``PurchasesError/verificationFailed``

### Other

- ``PurchasesError/unknown(_:)``

# ``PurchasesError``

The error every throwing call in **RKPurchaseKit** throws.

## Overview

Every throwing call on ``PurchasesManager`` throws a `PurchasesError`. StoreKit's own errors
(`StoreKitError`, `Product.PurchaseError`) are translated into the matching ``PurchasesError/code``,
so a caller can handle each failure without importing StoreKit's error types. The StoreKit error
itself is kept in ``PurchasesError/underlyingError``; anything without a dedicated code arrives as
``PurchasesError/Code/unknown``.

- ``PurchasesError/Code/notConfigured`` – `configure(identifiers:)` hasn’t been called.
- ``PurchasesError/Code/invalidProductID`` – StoreKit returned no `Product` for the ID in ``PurchasesError/productID``.
- ``PurchasesError/Code/purchaseCancelled`` – the user explicitly cancelled the transaction.
- ``PurchasesError/Code/purchasePending`` – the transaction is pending external action (e.g. Ask-to-Buy).
- ``PurchasesError/Code/unhandledPurchaseResult`` – StoreKit reported a purchase result newer than this SDK build.
- ``PurchasesError/Code/productUnavailable`` – the product exists but cannot be bought right now.
- ``PurchasesError/Code/purchaseNotAllowed`` – purchases are disabled on this device, for example by Screen Time.
- ``PurchasesError/Code/invalidQuantity`` – ``PurchaseOptions/quantity`` is out of the allowed range.
- ``PurchasesError/Code/ineligibleForOffer`` – the customer is not eligible for the requested offer.
- ``PurchasesError/Code/invalidOffer`` – the offer ID, price, signature or parameters were rejected.
- ``PurchasesError/Code/offerNotFound`` – the win-back offer ID in ``PurchaseOptions`` (also in ``PurchasesError/offerID``) is not on the product.
- ``PurchasesError/Code/paymentMethodBindingRequired`` – the App Store needs the customer to set up a payment method first.
- ``PurchasesError/Code/networkUnavailable`` – the App Store could not be reached.
- ``PurchasesError/Code/notAvailableInStorefront`` – the product is not sold in the customer's storefront.
- ``PurchasesError/Code/notEntitled`` – the app is not entitled to the requested StoreKit feature.
- ``PurchasesError/Code/unsupported`` – the operation is not supported on this platform or configuration.
- ``PurchasesError/Code/verificationFailed`` – StoreKit 2 signature could not be verified.
- ``PurchasesError/Code/unknown`` – any other failure. Its description is the underlying error's.

`StoreKitError.userCancelled` is reported as ``PurchasesError/Code/purchaseCancelled``, the same
as a cancelled purchase sheet, so one `catch` covers both.

### Catching an error

Match a code directly in a `catch` clause, as with Foundation's `CocoaError`. The shortcuts on
`PurchasesError` itself, such as ``PurchasesError/purchaseCancelled``, are the codes, and a code
matches any thrown `PurchasesError` that carries it. An error of another type matches no code.

```swift
do {
    _ = try await PurchasesManager.shared.purchase(productID: "com.myapp.pro")
} catch PurchasesError.purchaseCancelled {
    // No error UI needed.
} catch PurchasesError.networkUnavailable {
    showOfflineBanner()
} catch let error as PurchasesError where error.code == .invalidProductID {
    log("Unknown product \(error.productID ?? "")")
} catch {
    showAlert(error.localizedDescription)
}
```

To throw one, for example from a mock, pass the code and the detail it needs:

```swift
throw PurchasesError(.invalidProductID, productID: productID)
```

### A struct, not an enum

`PurchasesError` is a struct carrying an open ``PurchasesError/Code``, the design `CocoaError`
and `URLError` use. Until 4.0 it was an enum, so every failure StoreKit learned to report was a
new case and a source-breaking change for every exhaustive `switch`. A new code is now just a
new constant. The cost is that a `switch` over ``PurchasesError/code`` needs a `default` branch:

```swift
switch error.code {
case .purchaseCancelled, .purchasePending:
    break
case .networkUnavailable:
    showOfflineBanner()
default:
    showAlert(error.localizedDescription)
}
```

The type conforms to `Equatable`, comparing the code, ``PurchasesError/productID``,
``PurchasesError/offerID`` and the underlying error (as `NSError`). Because a translated StoreKit
error keeps its original, compare ``PurchasesError/code`` when the question is only which failure
it was. It also conforms to `LocalizedError`, so `localizedDescription` carries usable text.
See <doc:MigratingTo4>.

## Topics

### Creating an error

- ``PurchasesError/init(_:productID:offerID:underlyingError:)``

### Reading an error

- ``PurchasesError/code``
- ``PurchasesError/productID``
- ``PurchasesError/offerID``
- ``PurchasesError/underlyingError``
- ``PurchasesError/errorDescription``

### Codes

- ``PurchasesError/Code``

### Matching codes in catch clauses

- ``PurchasesError/notConfigured``
- ``PurchasesError/invalidProductID``
- ``PurchasesError/productUnavailable``
- ``PurchasesError/notAvailableInStorefront``
- ``PurchasesError/purchaseCancelled``
- ``PurchasesError/purchasePending``
- ``PurchasesError/purchaseNotAllowed``
- ``PurchasesError/invalidQuantity``
- ``PurchasesError/paymentMethodBindingRequired``
- ``PurchasesError/unhandledPurchaseResult``
- ``PurchasesError/ineligibleForOffer``
- ``PurchasesError/invalidOffer``
- ``PurchasesError/offerNotFound``
- ``PurchasesError/networkUnavailable``
- ``PurchasesError/notEntitled``
- ``PurchasesError/unsupported``
- ``PurchasesError/verificationFailed``
- ``PurchasesError/unknown``

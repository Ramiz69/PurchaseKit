# Migrating to PurchaseKit 4

Update an app or a test suite from PurchaseKit 3.x to 4.0.

## Overview

4.0 adds subscription status, offers and purchase options. Most call sites compile unchanged:
`purchase(productID:)`, `purchase(productID:appAccountToken:)` and `requestProducts()` are still
there. What breaks is code that switches over ``ProductType`` or ``PurchasesError`` - both are
now structs - code that builds a `PurchasesError` or a ``StoreTransaction`` itself, and types
that conform to the kit's protocols - typically the mocks in your tests and previews.

The platform floor is unchanged: OS 26 on every platform, Swift 6.2 tools.

### At a glance

| Change | Who is affected | Fix |
| --- | --- | --- |
| ``ProductType`` is a struct; `unknown` is gone | `switch` over `ProductType`, uses of `.unknown` | Add a `default` branch, or ask ``ProductType/isAutoRenewableSubscription`` |
| ``PurchasesError`` is a struct with a ``PurchasesError/Code`` | `switch` over the error, associated-value patterns, code that throws it | Switch over ``PurchasesError/code`` with a `default` branch; `throw PurchasesError(.code)` |
| StoreKit errors are now `PurchasesError` | `catch` clauses for `StoreKitError` / `Product.PurchaseError` | Catch the matching `PurchasesError` code |
| ``StoreTransaction`` initializer needs `productType` | Code that builds transactions (fixtures, mocks) | Pass the product's type |
| ``PurchasesProtocol`` requirements changed | Every conformer | Implement the new requirements |
| ``ServerVerifiedPurchasesProtocol`` lost a requirement | Every conformer | Move the token handling into `purchase(productID:options:)` |
| ``StoreProduct`` initializer needs `currencyCode` | Code that builds products (fixtures, mocks) | Pass the currency code |
| `activeSubscriptions()` includes bundles and suites | Code that assumed `.autoRenewable` only | Use `isAutoRenewableSubscription` |

## ProductType: a struct, with bundles and suites

``ProductType`` is now a `RawRepresentable` struct with one constant per kind, the pattern
StoreKit itself uses. As an enum, every kind StoreKit added - as the OS 27 SDKs did with
subscription bundles and suites - was another source-breaking release. As a struct, a kind
Apple adds later arrives as itself, with StoreKit's own ``ProductType/rawValue``, and a constant
for it can be added without breaking anyone.

Three things change for callers:

- A `switch` over a `ProductType` needs a `default` branch. The constants still read like cases.
- `ProductType.unknown` is gone. It existed because an enum had nowhere else to put a kind it
  did not know; a struct keeps that kind's raw value instead. Where you handled `.unknown`,
  handle `default`.
- Bundles and suites have their own constants, ``ProductType/subscriptionBundle`` and
  ``ProductType/subscriptionSuite``. In 3.x they arrived as `.unknown`.

```swift
// 3.x
switch product.type {
case .consumable, .nonConsumable, .nonRenewable:
    showOneTimePrice(product)
case .autoRenewable:
    showRenewalTerms(product)
case .unknown:
    hide(product)
}
```

```swift
// 4.0
switch product.type {
case .consumable, .nonConsumable, .nonRenewable:
    showOneTimePrice(product)
case .autoRenewable, .subscriptionBundle, .subscriptionSuite:
    showRenewalTerms(product)
default:
    hide(product)
}
```

If the question is only "does it renew?", skip the `switch`. The property stays correct when
StoreKit adds another subscription shape:

```swift
if product.type.isAutoRenewableSubscription {
    showRenewalTerms(product)
}
```

## PurchasesError: a struct with a code

``PurchasesError`` is now a struct carrying a ``PurchasesError/Code``, the design Foundation's
`CocoaError` and `URLError` use. With an enum, every failure StoreKit learned to report was a
new case and a breaking change; a new code is just a new constant. The details that used to be
associated values are properties: ``PurchasesError/productID`` for
``PurchasesError/Code/invalidProductID``, ``PurchasesError/offerID`` for
``PurchasesError/Code/offerNotFound`` and ``PurchasesError/underlyingError`` for
``PurchasesError/Code/unknown`` - and for every error translated from StoreKit.

### Catching

`catch PurchasesError.purchaseCancelled` compiles and matches exactly as before: the shortcuts
on `PurchasesError`, such as ``PurchasesError/purchaseCancelled``, are codes, and a code matches
any thrown `PurchasesError` that carries it. A thrown error of another type matches no code. To
read the details, bind the error and compare ``PurchasesError/code``:

```swift
// 3.x
do {
    _ = try await purchases.purchase(productID: id)
} catch PurchasesError.purchaseCancelled {
} catch PurchasesError.invalidProductID(let productID) {
    log("Unknown product \(productID)")
}
```

```swift
// 4.0
do {
    _ = try await purchases.purchase(productID: id)
} catch PurchasesError.purchaseCancelled {
} catch let error as PurchasesError where error.code == .invalidProductID {
    log("Unknown product \(error.productID ?? id)")
}
```

### Switching

A `switch` goes over ``PurchasesError/code`` and needs a `default` branch:

```swift
// 3.x
switch error {
case .purchaseCancelled, .purchasePending:
    break
case .unknown(let underlying):
    report(underlying)
default:
    showAlert(error.localizedDescription)
}
```

```swift
// 4.0
switch error.code {
case .purchaseCancelled, .purchasePending:
    break
case .unknown:
    report(error.underlyingError)
default:
    showAlert(error.localizedDescription)
}
```

### Throwing

Mocks and tests that throw the error build it from a code:

```swift
// 3.x
throw PurchasesError.invalidProductID(productID)
throw PurchasesError.purchaseCancelled
```

```swift
// 4.0
throw PurchasesError(.invalidProductID, productID: productID)
throw PurchasesError(.purchaseCancelled)
```

The type is still `Equatable` and `LocalizedError`. Equality compares the code, the identifiers
and the underlying error, so `#expect(throws: PurchasesError(.invalidProductID, productID: "x"))`
works as before; for an error translated from StoreKit, compare ``PurchasesError/code`` instead,
because it also carries the StoreKit original.

### StoreKit failures get their own codes

In 3.x the manager threw ``PurchasesError`` only for the failures it detected itself. Errors
from StoreKit - `StoreKitError` and `Product.PurchaseError` - propagated unchanged, so a
`catch` for `PurchasesError` missed a network failure or a disabled purchase, and the error
had to be matched against StoreKit's types.

In 4.0 every throwing call throws `PurchasesError`. StoreKit errors map to these new codes, and
the StoreKit error is kept as ``PurchasesError/underlyingError``:

| StoreKit error | 4.0 code |
| --- | --- |
| `Product.PurchaseError.productUnavailable` | ``PurchasesError/Code/productUnavailable`` |
| `Product.PurchaseError.purchaseNotAllowed` | ``PurchasesError/Code/purchaseNotAllowed`` |
| `Product.PurchaseError.invalidQuantity` | ``PurchasesError/Code/invalidQuantity`` |
| `Product.PurchaseError.ineligibleForOffer` | ``PurchasesError/Code/ineligibleForOffer`` |
| `Product.PurchaseError.invalidOfferIdentifier`, `.invalidOfferPrice`, `.invalidOfferSignature`, `.missingOfferParameters` | ``PurchasesError/Code/invalidOffer`` |
| `Product.PurchaseError.paymentMethodBindingConfigurationRequired` | ``PurchasesError/Code/paymentMethodBindingRequired`` |
| `StoreKitError.networkError` | ``PurchasesError/Code/networkUnavailable`` |
| `StoreKitError.notAvailableInStorefront` | ``PurchasesError/Code/notAvailableInStorefront`` |
| `StoreKitError.notEntitled` | ``PurchasesError/Code/notEntitled`` |
| `StoreKitError.unsupported` | ``PurchasesError/Code/unsupported`` |
| `StoreKitError.userCancelled` | ``PurchasesError/Code/purchaseCancelled`` |
| anything else | ``PurchasesError/Code/unknown`` |

``PurchasesError/Code/offerNotFound`` is new as well: it reports a
``PurchaseOptions/winBackOfferID`` that the product does not offer.

```swift
// 3.x
do {
    _ = try await purchases.purchase(productID: "com.myapp.pro")
} catch PurchasesError.purchaseCancelled {
} catch let error as StoreKitError {
    if case .networkError = error { showOfflineBanner() }
} catch {
    showAlert(error)
}
```

```swift
// 4.0
do {
    _ = try await purchases.purchase(productID: "com.myapp.pro")
} catch PurchasesError.purchaseCancelled {
} catch PurchasesError.networkUnavailable {
    showOfflineBanner()
} catch {
    showAlert(error)
}
```

## PurchasesProtocol: what a mock implements now

Purchases take ``PurchaseOptions``, so the purchase requirement is now
``PurchasesProtocol/purchase(productID:options:)``. `purchase(productID:)` became an extension
method that passes ``PurchaseOptions/none``. Three requirements are new:
``PurchasesProtocol/subscriptionStatuses(inGroup:)``,
``PurchasesProtocol/isEligibleForIntroOffer(inGroup:)`` and
``PurchasesProtocol/appPurchaseInfo()``.

```swift
// 3.x
struct PurchasesMock: PurchasesProtocol {
    var result: (product: StoreProduct, transaction: StoreTransaction)

    func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [result.product] }
    func purchase(productID: String) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        result
    }
    func restore() async throws { }
    func hasEntitlement(for productID: String) async -> Bool { false }
    func entitlementProductIDs() async -> Set<String> { [] }
    func activeSubscriptions() async -> [StoreProduct] { [] }
    func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
}
```

```swift
// 4.0
struct PurchasesMock: PurchasesProtocol {
    var result: (product: StoreProduct, transaction: StoreTransaction)

    func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [result.product] }
    func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        result
    }
    func restore() async throws { }
    func hasEntitlement(for productID: String) async -> Bool { false }
    func entitlementProductIDs() async -> Set<String> { [] }
    func activeSubscriptions() async -> [StoreProduct] { [] }
    func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
    func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] { [] }
    func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool { true }
    func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError(.unsupported) }
}
```

Rename the old method rather than keeping it next to the new one. A leftover
`purchase(productID:)` in the mock still compiles, but it no longer satisfies a requirement:
code that holds `any PurchasesProtocol` calls the extension method instead, which forwards to
`purchase(productID:options:)`, and the mock's own version never runs.

``PurchasesProtocol/subscriptionStatus(inGroup:)`` and ``PurchasesProtocol/requestProducts()``
are extension methods too; a mock gets them for free.

On visionOS the requirement is `purchase(productID:options:confirmIn:)` and
`purchase(productID:confirmIn:)` is the extension method.

## ServerVerifiedPurchasesProtocol: the token is an option

The account token is now part of ``PurchaseOptions``, so
``ServerVerifiedPurchasesProtocol/purchase(productID:appAccountToken:)`` is an extension method
that builds `PurchaseOptions(appAccountToken:)` and calls `purchase(productID:options:)`. It is
no longer a requirement. Call sites are unchanged; a conformer moves its logic:

```swift
// 3.x
final class ServerMock: ServerVerifiedPurchasesProtocol {
    // ...the PurchasesProtocol requirements...
    func purchase(
        productID: String,
        appAccountToken: UUID?
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        recordedToken = appAccountToken
        return result
    }
}
```

```swift
// 4.0
final class ServerMock: ServerVerifiedPurchasesProtocol {
    // ...the PurchasesProtocol requirements...
    func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        recordedToken = options.appAccountToken
        return result
    }
}
```

``ServerVerifiedPurchasesProtocol/transactionUpdates``, ``ServerVerifiedPurchasesProtocol/finish(_:)``
and ``ServerVerifiedPurchasesProtocol/unfinishedTransactions()`` are unchanged.

## StoreProduct: the initializer needs a currency code

``StoreProduct`` now carries ``StoreProduct/currencyCode``, and the public initializer takes it
right after `displayPrice`. There is no default: a price without its currency cannot be
formatted or reported, and any default would be wrong somewhere.

```swift
// 3.x
StoreProduct(
    productID: "com.myapp.pro",
    type: .nonConsumable,
    displayName: "Pro",
    description: "Unlock everything",
    price: 9.99,
    displayPrice: "$9.99"
)
```

```swift
// 4.0
StoreProduct(
    productID: "com.myapp.pro",
    type: .nonConsumable,
    displayName: "Pro",
    description: "Unlock everything",
    price: 9.99,
    displayPrice: "$9.99",
    currencyCode: "USD"
)
```

The other new fields - ``StoreProduct/subscriptionPeriod``, ``StoreProduct/introductoryOffer``,
``StoreProduct/promotionalOffers`` and ``StoreProduct/winBackOffers`` - default to `nil` or an
empty array.

## StoreTransaction: the initializer needs a product type

``StoreTransaction`` now carries ``StoreTransaction/productType``, and the public initializer
takes it right after `productID`. There is no default: a transaction is always for some kind of
product, and guessing one was the only reason `ProductType.unknown` existed.

```swift
// 3.x
StoreTransaction(id: 1, productID: "com.myapp.pro", purchaseDate: .now)
```

```swift
// 4.0
StoreTransaction(id: 1, productID: "com.myapp.pro", productType: .nonConsumable, purchaseDate: .now)
```

The other new fields - ``StoreTransaction/environment``, ``StoreTransaction/offer``,
``StoreTransaction/ownershipType`` and more - are appended to the initializer with defaults.

## activeSubscriptions includes bundles and suites

``PurchasesManager/activeSubscriptions()`` and
``PurchasesManager/activeSubscription(inGroup:)`` used to consider only products whose type is
``ProductType/autoRenewable``. They now use ``ProductType/isAutoRenewableSubscription``, so an
active subscription bundle or suite is returned too. If you filter the result by
`type == .autoRenewable`, switch to the property, or a bundle subscriber will look unsubscribed.

```swift
// 3.x
let renewing = active.filter { $0.type == .autoRenewable }
```

```swift
// 4.0
let renewing = active.filter { $0.type.isAutoRenewableSubscription }
```

## What else is new

None of these require changes:

- ``StoreSubscriptionStatus`` and ``PurchasesManager/subscriptionStatusUpdates`` - see <doc:Subscriptions>.
- ``PurchaseOptions``: quantity, promotional and win-back offers, intro-offer eligibility,
  Ask to Buy in the sandbox.
- ``AppPurchaseInfo`` from ``PurchasesManager/appPurchaseInfo()``.
- ``PurchasesManager/unavailableProductIDs`` lists configured identifiers StoreKit did not
  return, and ``PurchasesManager/currentStorefrontCountryCode()`` reads the storefront.
- On iOS and visionOS: `showManageSubscriptions(in:groupID:)`, `beginRefundRequest(for:in:)`
  returning ``RefundRequestStatus``, and `presentOfferCodeRedeemSheet(in:)`.

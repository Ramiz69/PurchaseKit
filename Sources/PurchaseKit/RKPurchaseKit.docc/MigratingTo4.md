# Migrating to PurchaseKit 4

Update an app or a test suite from PurchaseKit 3.x to 4.0.

## Overview

4.0 adds subscription status, offers and purchase options. Most call sites compile unchanged:
`purchase(productID:)`, `purchase(productID:appAccountToken:)` and `requestProducts()` are still
there. What breaks is code that switches exhaustively over the kit's enums, and types that
conform to its protocols - typically the mocks in your tests and previews.

The platform floor is unchanged: OS 26 on every platform, Swift 6.2 tools.

### At a glance

| Change | Who is affected | Fix |
| --- | --- | --- |
| ``ProductType`` gained two cases | Exhaustive `switch` over `ProductType` | Add the cases, or ask ``ProductType/isAutoRenewableSubscription`` |
| ``PurchasesError`` gained eleven cases | Exhaustive `switch` over `PurchasesError` | Add the cases, or a `default` branch |
| StoreKit errors are now `PurchasesError` | `catch` clauses for `StoreKitError` / `Product.PurchaseError` | Catch the matching `PurchasesError` case |
| ``PurchasesProtocol`` requirements changed | Every conformer | Implement the new requirements |
| ``ServerVerifiedPurchasesProtocol`` lost a requirement | Every conformer | Move the token handling into `purchase(productID:options:)` |
| ``StoreProduct`` initializer needs `currencyCode` | Code that builds products (fixtures, mocks) | Pass the currency code |
| `activeSubscriptions()` includes bundles and suites | Code that assumed `.autoRenewable` only | Use `isAutoRenewableSubscription` |

## ProductType: subscription bundles and suites

StoreKit added two shapes of auto-renewable subscription: bundles and suites. They used to
arrive as ``ProductType/unknown``; they now have their own cases,
``ProductType/subscriptionBundle`` and ``ProductType/subscriptionSuite``. A `switch` without a
`default` branch stops compiling:

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
case .unknown:
    hide(product)
}
```

If the question is only "does it renew?", skip the `switch`. The new property stays correct
when StoreKit adds another subscription shape:

```swift
if product.type.isAutoRenewableSubscription {
    showRenewalTerms(product)
}
```

## PurchasesError: StoreKit failures get their own cases

In 3.x the manager threw ``PurchasesError`` only for the failures it detected itself. Errors
from StoreKit - `StoreKitError` and `Product.PurchaseError` - propagated unchanged, so a
`catch` for `PurchasesError` missed a network failure or a disabled purchase, and the error
had to be matched against StoreKit's types.

In 4.0 every throwing call throws `PurchasesError`. StoreKit errors map to these new cases:

| StoreKit error | 4.0 case |
| --- | --- |
| `Product.PurchaseError.productUnavailable` | ``PurchasesError/productUnavailable`` |
| `Product.PurchaseError.purchaseNotAllowed` | ``PurchasesError/purchaseNotAllowed`` |
| `Product.PurchaseError.invalidQuantity` | ``PurchasesError/invalidQuantity`` |
| `Product.PurchaseError.ineligibleForOffer` | ``PurchasesError/ineligibleForOffer`` |
| `Product.PurchaseError.invalidOfferIdentifier`, `.invalidOfferPrice`, `.invalidOfferSignature`, `.missingOfferParameters` | ``PurchasesError/invalidOffer`` |
| `Product.PurchaseError.paymentMethodBindingConfigurationRequired` | ``PurchasesError/paymentMethodBindingRequired`` |
| `StoreKitError.networkError` | ``PurchasesError/networkUnavailable`` |
| `StoreKitError.notAvailableInStorefront` | ``PurchasesError/notAvailableInStorefront`` |
| `StoreKitError.notEntitled` | ``PurchasesError/notEntitled`` |
| `StoreKitError.unsupported` | ``PurchasesError/unsupported`` |
| `StoreKitError.userCancelled` | ``PurchasesError/purchaseCancelled`` |
| anything else | ``PurchasesError/unknown(_:)`` |

``PurchasesError/offerNotFound(_:)`` is new as well: it reports a
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

An exhaustive `switch` over `PurchasesError` needs the new cases or a `default` branch. The
type is still `Equatable` and `LocalizedError`, and every new case has a description.

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
    func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError.unsupported }
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

``StoreTransaction`` gained fields as well (``StoreTransaction/productType``,
``StoreTransaction/environment``, ``StoreTransaction/offer`` and more). They are appended to its
initializer with defaults, so existing calls compile unchanged.

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

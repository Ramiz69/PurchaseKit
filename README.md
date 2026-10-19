# RKPurchaseKit

[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FRamiz69%2FPurchaseKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Ramiz69/PurchaseKit)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FRamiz69%2FPurchaseKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Ramiz69/PurchaseKit)

A lightweight Swift framework for in-app purchases using StoreKit 2  
with full support for Swift Concurrency, async/await, and SPM.

## 📦 Installation

### Swift Package Manager

Add this URL to your Xcode project:

```text
https://github.com/Ramiz69/PurchaseKit.git
```
In Package.swift:
```text
.package(url: "https://github.com/Ramiz69/PurchaseKit.git", from: "4.0.0")
```

### ✅ Features
- async/await API
- actor-based PurchasesManager
- Typed errors: StoreKit failures arrive as `PurchasesError` codes (`networkUnavailable`, `purchaseNotAllowed`, …), matched with `catch PurchasesError.purchaseCancelled`
- Purchase options: account token, quantity, promotional offers (server-signed JWS), win-back offers
- Subscription status: renewal info, grace period and billing retry, intro-offer eligibility, live status updates
- Subscription bundles and suites (`ProductType.isAutoRenewableSubscription`)
- Server-verified purchases with manual finishing
- App purchase info (`AppTransaction`) for paid-to-free migrations
- Every model has a public initializer, so `PurchasesProtocol` is fully mockable
- DocC documentation
- Support for iOS, macOS, Mac Catalyst, tvOS, watchOS, visionOS (26 and later)

### 🔁 Subscription status

```swift
let purchases = PurchasesManager.shared

if let status = try await purchases.subscriptionStatus(inGroup: "com.myapp.subscriptions.premium") {
    switch status.state {
    case .inGracePeriod, .inBillingRetryPeriod:
        showUpdatePaymentBanner()          // the renewal payment failed
    case .subscribed where !status.willAutoRenew:
        showResubscribeHint()              // turned off auto-renew
    default:
        break
    }
}

Task {
    for await status in purchases.subscriptionStatusUpdates {
        await model.apply(status)          // renewals, expirations, plan changes
    }
}
```

Before showing a free trial, ask `isEligibleForIntroOffer(inGroup:)`. Promotional offers are
signed on your server and passed in `PurchaseOptions(promotionalOffer:)`; win-back offers come
from `StoreProduct.winBackOffers` and need no signature.

### 🧾 Server-verified consumables

If your server credits purchases to an account, finish transactions only after it has
accepted them - a finished consumable is never redelivered:

```swift
PurchasesManager.configure(identifiers: ["com.myapp.coins.100"], finishing: .manual)

let (_, transaction) = try await PurchasesManager.shared
    .purchase(productID: "com.myapp.coins.100", appAccountToken: user.id)
try await api.creditPurchase(signed: transaction.jwsRepresentation!)
await PurchasesManager.shared.finish(transaction)
```

Also handle `transactionUpdates` (Ask to Buy, pending payments, replays at launch) and drain
`unfinishedTransactions()` at launch. Everything here is additive: the default stays
`.automatic`, and existing code behaves exactly as before.

### 🕶 visionOS

StoreKit has no scene-less purchase call on visionOS, so `purchase(productID:)` is not available there. Use `purchase(productID:confirmIn:)` and pass the scene the customer is interacting with:

```swift
let result = try await PurchasesManager.shared.purchase(productID: "pro.monthly", confirmIn: scene)
```

In SwiftUI, StoreKit's `PurchaseAction` from the environment resolves the scene for you.

### ⚠️ Migrating to 4.0

Call sites mostly compile unchanged. What breaks:

- **`ProductType` is a struct** with StoreKit's raw values, so a kind Apple adds later is no longer a breaking change. A `switch` over it needs a `default` branch; `ProductType.unknown` is gone (an unfamiliar kind keeps its raw value instead); `subscriptionBundle` and `subscriptionSuite` are new.
- **`PurchasesError` is a struct with a `code`**, like `CocoaError`. `catch PurchasesError.purchaseCancelled` still works; read details with `catch let error as PurchasesError where error.code == .invalidProductID` and `error.productID` / `error.offerID` / `error.underlyingError`. A `switch` goes over `error.code` and needs a `default` branch. Throw it as `PurchasesError(.invalidProductID, productID: id)`.
- **StoreKit errors are now `PurchasesError`.** A `catch let error as StoreKitError` no longer matches; catch the code instead (`.networkUnavailable`, `.purchaseNotAllowed`, …). The StoreKit error is kept as `underlyingError`.
- **`StoreTransaction(…)`** requires `productType:` after `productID:`.
- **`PurchasesProtocol` mocks** implement `purchase(productID:options:)` instead of `purchase(productID:)`, plus `subscriptionStatuses(inGroup:)`, `isEligibleForIntroOffer(inGroup:)` and `appPurchaseInfo()`. `ServerVerifiedPurchasesProtocol` no longer requires `purchase(productID:appAccountToken:)`; both short forms are extension methods now.
- **`StoreProduct(…)`** requires `currencyCode:` after `displayPrice:`.
- **`activeSubscriptions()`** now includes subscription bundles and suites.

The full guide with before/after code: [Migrating to PurchaseKit 4](https://ramiz69.github.io/PurchaseKit/documentation/rkpurchasekit/migratingto4).

### ⚠️ Migrating to 3.0

**From 2.0** — one change affects you:

- **`purchase(productID:)` returns a `StoreTransaction`** instead of a raw `StoreKit.Transaction`. The fields you were reading are on it under the same names, and the raw value is still available as `.transaction`. `StoreKit.Transaction` has no public initializer, so while `purchase` returned one, a stand-in implementation could only throw and never represent a successful purchase — which defeated the point of having a protocol to mock.

**From 1.x** — everything in 2.0 applies as well:

- **Platforms** now start at iOS/macOS/tvOS/watchOS/visionOS **26**. Earlier releases are no longer supported; stay on 1.0.6 if you need them.
- **`StoreProduct.product` is now optional.** It is `nil` on values you build yourself, because `StoreKit.Product` cannot be constructed outside StoreKit. There is now a public initializer taking the fields directly, so `PurchasesProtocol` can be mocked in tests and previews.
- **`ProductType` gained `unknown`** and `PurchasesError` gained `unhandledPurchaseResult`. Exhaustive `switch` statements over either need a new branch. A StoreKit product type this SDK does not recognise now reports `unknown` instead of silently passing as `nonConsumable`.
- **`purchasedProducts` no longer replays past events.** Every access returns a fresh stream, so several observers can watch at once — previously two `for await` loops split the events between them and each missed the rest. Read current state with `hasEntitlement(for:)` or `requestProducts(includingCache:)` when a subscriber starts.
- **`requestProducts()` with no arguments** is now a distinct overload on `PurchasesProtocol`. Calls are unchanged; only a conformer that relied on the default implementation is affected, and that case no longer compiles rather than recursing forever at runtime.
- `PurchasesError` now conforms to `Equatable` and `LocalizedError`, and `PurchasesManager.resolved()` returns the singleton by throwing `notConfigured` instead of trapping like `shared`.

### 📚 Documentation

- 🧭 [Online documentation →](https://ramiz69.github.io/PurchaseKit)
- 🛠 In Xcode: `Product > Build Documentation`

### 📄 License

```text
MIT © Ramiz Kichibekov
```

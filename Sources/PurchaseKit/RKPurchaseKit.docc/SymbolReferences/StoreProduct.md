# ``StoreProduct``

Value type describing a product, enriched with a few convenience fields for UI and entitlement state.

Normally the kit builds these for you from `StoreKit.Product`, and ``StoreProduct/product`` carries the product it was read from. You can also build one directly with the public initializer, for tests, SwiftUI previews and mock implementations of ``PurchasesProtocol``; ``StoreProduct/product`` is `nil` on those, because `StoreKit.Product` has no public initializer and cannot be created outside StoreKit.

## Properties

- ``StoreProduct/product`` – the backing `StoreKit.Product`, `nil` when the value was not read from StoreKit
- ``StoreProduct/productID``
- ``StoreProduct/type``
- ``StoreProduct/displayName``
- ``StoreProduct/price`` – the numeric price, in ``StoreProduct/currencyCode``
- ``StoreProduct/displayPrice``
- ``StoreProduct/currencyCode`` – ISO 4217 code of the storefront currency, e.g. `"USD"`
- ``StoreProduct/isPurchased``
- ``StoreProduct/subscriptionGroupID``
- ``StoreProduct/subscriptionPeriod`` – how often an auto-renewable subscription renews
- ``StoreProduct/introductoryOffer`` – the free trial or intro price, if configured
- ``StoreProduct/promotionalOffers`` – offers you sign on your server and pass in ``PurchaseOptions``
- ``StoreProduct/winBackOffers`` – offers for customers whose subscription has lapsed

> Tip: For auto-renewable subscriptions, `subscriptionGroupID` helps you select the “best” active subscription within a group (see ``PurchasesManager/activeSubscription(inGroup:)``).

`introductoryOffer` says what the offer is, not whether this customer can have it. Ask
``PurchasesManager/isEligibleForIntroOffer(inGroup:)`` before advertising it. See
<doc:Subscriptions>.

## Building one for tests

`currencyCode` is required: a price without a currency cannot be formatted or reported
correctly, and no default would be right for every storefront. The subscription fields
default to `nil` and empty arrays.

```swift
let monthly = StoreProduct(
    productID: "com.myapp.sub.premium.monthly",
    type: .autoRenewable,
    displayName: "Premium Monthly",
    description: "All features, billed monthly",
    price: 4.99,
    displayPrice: "$4.99",
    currencyCode: "USD",
    subscriptionGroupID: "com.myapp.subscriptions.premium",
    subscriptionPeriod: StoreSubscriptionPeriod(value: 1, unit: .month)
)
```

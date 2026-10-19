# ``ProductType``

The kind of an App Store product, mirroring `StoreKit.Product.ProductType`.

## Overview

- ``ProductType/nonConsumable`` – bought once and owned for good, such as a premium unlock
- ``ProductType/consumable`` – used up and bought again, such as in-game currency
- ``ProductType/nonRenewable`` – a subscription for a fixed period that does not renew
- ``ProductType/autoRenewable`` – a subscription that renews until cancelled
- ``ProductType/subscriptionBundle`` – several subscriptions sold together as one auto-renewable product
- ``ProductType/subscriptionSuite`` – a group of subscriptions that unlock each other's content

Bundles and suites renew like any other auto-renewable subscription. When the question is
"does this renew?", ask ``ProductType/isAutoRenewableSubscription`` instead of comparing
against ``ProductType/autoRenewable``: the property is `true` for all three kinds, so code
written against it keeps working as StoreKit adds subscription shapes.

```swift
if product.type.isAutoRenewableSubscription {
    showRenewalTerms(for: product)
}
```

### A struct, not an enum

`ProductType` is a `RawRepresentable` struct with one constant per kind, the same pattern
StoreKit uses for `Product.ProductType`. Until 4.0 it was an enum, so every kind StoreKit added
was a source-breaking change for every exhaustive `switch`. As a struct, a kind Apple adds later
arrives as itself and a constant for it can be added without breaking anyone.

The ``ProductType/rawValue`` is StoreKit's own (`"Consumable"`, `"Non-Consumable"`,
`"Non-Renewing Subscription"`, `"Auto-Renewable Subscription"`, `"Subscription Bundle"`,
`"Subscription Suite"`), so a kind this build has no constant for reads exactly as StoreKit
reported it. There is no catch-all `unknown` value: an unfamiliar kind is not equal to any
constant, and ``ProductType/isAutoRenewableSubscription`` is `false` for it.

A `switch` over a `ProductType` matches the constants with `==`, and needs a `default` branch:

```swift
switch product.type {
case .consumable, .nonConsumable, .nonRenewable:
    showOneTimePrice(product)
case .autoRenewable, .subscriptionBundle, .subscriptionSuite:
    showRenewalTerms(product)
default:
    hide(product) // A kind newer than this build: assume nothing about what it grants.
}
```

See <doc:MigratingTo4>.

## Topics

### Product kinds

- ``ProductType/nonConsumable``
- ``ProductType/consumable``
- ``ProductType/nonRenewable``
- ``ProductType/autoRenewable``
- ``ProductType/subscriptionBundle``
- ``ProductType/subscriptionSuite``

### Classification

- ``ProductType/isAutoRenewableSubscription``

### Raw value

- ``ProductType/init(rawValue:)``
- ``ProductType/rawValue``

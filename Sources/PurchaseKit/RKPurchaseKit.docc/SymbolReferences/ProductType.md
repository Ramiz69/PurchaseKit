# ``ProductType``

Thin enum mapping `StoreKit.Product.ProductType` to an SDK-friendly representation.

## Overview

- ``ProductType/nonConsumable``
- ``ProductType/consumable``
- ``ProductType/nonRenewable``
- ``ProductType/autoRenewable``
- ``ProductType/subscriptionBundle`` – several subscriptions sold together as one auto-renewable product
- ``ProductType/subscriptionSuite`` – a group of subscriptions that unlock each other's content
- ``ProductType/unknown`` – a StoreKit kind newer than this SDK build; do not infer entitlement from it

Bundles and suites renew like any other auto-renewable subscription. When the question is
"does this renew?", ask ``ProductType/isAutoRenewableSubscription`` instead of comparing
against ``ProductType/autoRenewable``: the property is `true` for all three kinds, so code
written against it keeps working as StoreKit adds subscription shapes.

```swift
if product.type.isAutoRenewableSubscription {
    showRenewalTerms(for: product)
}
```

`ProductType` stays an `enum` so that a `switch` over it is checked by the compiler. The cost
is that every new case is a source-breaking change for exhaustive switches; 4.0 added two. See
<doc:MigratingTo4>.

## Topics

### Product kinds

- ``ProductType/nonConsumable``
- ``ProductType/consumable``
- ``ProductType/nonRenewable``
- ``ProductType/autoRenewable``
- ``ProductType/subscriptionBundle``
- ``ProductType/subscriptionSuite``
- ``ProductType/unknown``

### Classification

- ``ProductType/isAutoRenewableSubscription``

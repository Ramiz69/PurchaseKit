# ``StoreSubscriptionPeriod``

A length of time, such as one month or two weeks, that a subscription or an offer runs for.

## Overview

Used by ``StoreProduct/subscriptionPeriod`` for the renewal interval and by
``SubscriptionOffer/period`` for one billing period of an offer.

```swift
let yearly = StoreSubscriptionPeriod(value: 1, unit: .year)
```

``Unit`` is an `enum`: calendar units do not change, so an exhaustive `switch` over it is safe.

## Topics

### Length
- ``value``
- ``unit``
- ``Unit``

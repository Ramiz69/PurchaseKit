# ``SubscriptionOffer``

A discount a subscription product offers: a free trial, an introductory price, a promotional
offer, a win-back offer or an offer code.

## Overview

Read offers from ``StoreProduct/introductoryOffer``, ``StoreProduct/promotionalOffers`` and
``StoreProduct/winBackOffers``. Each describes the terms, which is enough to render them:

```swift
func introLabel(for product: StoreProduct) async -> String? {
    guard let intro = product.introductoryOffer,
          let groupID = product.subscriptionGroupID,
          await PurchasesManager.shared.isEligibleForIntroOffer(inGroup: groupID) else {
        return nil
    }
    if intro.paymentMode == .freeTrial {
        return "Free for \(intro.period.value * intro.periodCount) \(intro.period.unit)(s)"
    }
    return "\(intro.displayPrice) per period for \(intro.periodCount) periods"
}
```

The price covers one ``period``; the offer lasts ``periodCount`` periods. ``id`` is `nil` for
an introductory offer, which App Store Connect does not name.

``OfferType`` and ``PaymentMode`` are `RawRepresentable` structs, so a future StoreKit value is
representable and adding one is not a breaking change. ``OfferType`` is also used by
``StoreTransaction/Offer`` to say which kind of offer a transaction redeemed.

## Topics

### Identity
- ``id``
- ``type``
- ``OfferType``

### Terms
- ``paymentMode``
- ``PaymentMode``
- ``price``
- ``displayPrice``
- ``period``
- ``periodCount``

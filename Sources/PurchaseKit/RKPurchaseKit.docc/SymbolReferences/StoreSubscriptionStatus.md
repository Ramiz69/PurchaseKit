# ``StoreSubscriptionStatus``

The renewal state of a subscription group for the current customer.

## Overview

``PurchasesManager/subscriptionStatuses(inGroup:)`` returns one status per subscription the
customer holds in a group - usually one, more with Family Sharing.
``PurchasesProtocol/subscriptionStatus(inGroup:)`` picks the one that matters most: subscribed
first, then grace period, billing retry, expired and revoked, and the latest expiration date
when two share a state.

Use the status for what an entitlement check cannot tell you: that the subscription will not
renew, that a payment is failing, or which plan it renews into.

```swift
guard let status = try await PurchasesManager.shared
    .subscriptionStatus(inGroup: "com.myapp.subscriptions.premium") else {
    showPaywall()
    return
}

switch status.state {
case .inGracePeriod, .inBillingRetryPeriod:
    showUpdatePaymentBanner(until: status.gracePeriodExpirationDate)
case .subscribed where !status.willAutoRenew:
    showResubscribeHint(endingOn: status.transaction.expirationDate)
default:
    break
}
```

``isActive`` is `true` while the customer should have access: subscribed or in a grace
period. During a billing retry period without a grace period, the App Store has already
withdrawn the entitlement.

The renewal fields come from the signed renewal info. If it fails verification they read as
`nil` or `false` rather than trusting unverified data; a status whose transaction fails
verification is left out entirely.

``State`` and ``ExpirationReason`` are `RawRepresentable` structs, so a `switch` over them
needs a `default` branch and a future StoreKit value does not break your build.

See <doc:Subscriptions>.

## Topics

### State
- ``state``
- ``isActive``
- ``State``

### Subscription
- ``groupID``
- ``transaction``

### Renewal
- ``willAutoRenew``
- ``autoRenewProductID``
- ``renewalDate``
- ``expirationReason``
- ``ExpirationReason``

### Billing problems
- ``isInBillingRetry``
- ``gracePeriodExpirationDate``

### Server verification
- ``renewalInfoJWS``

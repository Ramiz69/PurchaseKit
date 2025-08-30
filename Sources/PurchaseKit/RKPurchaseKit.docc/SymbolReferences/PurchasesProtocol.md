# ``PurchasesProtocol``

An abstraction that lets you swap ``PurchasesManager`` for a mock implementation in unit tests or previews.

The protocol mirrors the public surface of the manager and adds high-level helpers for entitlements and subscriptions.

## Topics

### Core Methods
- ``requestProducts(includingCache:)``
- ``purchase(productID:)``
- ``restore()``

### Entitlements & Subscriptions
- ``hasEntitlement(for:)``
- ``entitlementProductIDs()``
- ``activeSubscriptions()``
- ``activeSubscription(inGroup:)``

### Default Implementations
`PurchasesProtocol` ships with a default parameter for `includingCache` so most callers can write:

```swift
let products = try await manager.requestProducts()
```

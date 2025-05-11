# ``PurchasesProtocol``

An abstraction that lets you swap `PurchasesManager` for a mock implementation in unit-tests or previews.

## Topics

### Core Methods
* ``PurchasesProtocol/requestProducts(includingCache:)``
* ``PurchasesProtocol/purchase(productID:)``
* ``PurchasesProtocol/restore()``

### Default Implementations
`PurchasesProtocol` ships with a default parameter for `includingCache` so most callers can write just:

```swift
let products = try await manager.requestProducts()
```

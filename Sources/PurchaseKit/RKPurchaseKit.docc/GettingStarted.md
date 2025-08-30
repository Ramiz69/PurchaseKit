# Getting Started

Welcome to **RKPurchaseKit**!  
This quick guide walks you through the four-step integration flow.

---
## 1  Configure the SDK <a id="configure"></a>

Call **once** at app launch (e.g. inside
`application(_:didFinishLaunchingWithOptions:)`):

```swift
import RKPurchaseKit

PurchasesManager.configure(identifiers: [
    "com.myapp.pro",
    "com.myapp.consumable.coin",
    "com.myapp.sub.premium.monthly",
    "com.myapp.sub.premium.yearly"
])
```

> **Tip**  
> If `configure(identifiers:)` isn’t called, any later access to
> ``PurchasesManager/shared`` will trap in **Debug** builds to highlight the mistake.

---
## 2  Fetch products <a id="fetch-products"></a>

```swift
let products: [StoreProduct] =
    try await PurchasesManager.shared.requestProducts()
```

* Results are cached; repeat calls are instant & offline-safe.  
* Pass `includingCache: false` to force a fresh fetch.

---
## 3  Make a purchase <a id="purchase"></a>

```swift
do {
    let product = try await PurchasesManager.shared
                        .purchase(productID: "com.myapp.pro")
    print("🎉 Purchased:", product.displayName)
} catch PurchasesError.purchaseCancelled {
    // user tapped “Cancel” – usually no error UI needed
} catch {
    // handle / log other errors
}
```

The call throws typed errors defined in ``PurchasesError``.

---
## 4  Listen to purchase events

```swift
Task {
    for await event in PurchasesManager.shared.purchasedProducts {
        // hop to the main actor if you update UI
        await MainActor.run {
            print("✅ Entitlement updated:", event.product.productID)
        }
    }
}
```

`purchasedProducts` emits **both** new purchases and restored entitlements,
so your UI stays in sync without delegates.

---
## 5  Restore past purchases

```swift
try await PurchasesManager.shared.restore()
```

Provide an explicit “Restore Purchases” button if required by App Store Review.

---
## 6  Gate features by entitlement 

Use current entitlements to unlock features (no receipt parsing needed):

```swift
let hasPro = await PurchasesManager.shared.hasEntitlement(for: "com.myapp.pro")

if hasPro {
    // unlock premium UI
}
```
Or quickly check all entitled product identifiers:
```swift
let ids = await PurchasesManager.shared.entitlementProductIDs()
```
See: ``PurchasesManager/hasEntitlement(for:)``, ``PurchasesManager/entitlementProductIDs()``
---
## 7  Work with subscriptions (groups) 

List all active auto-renewable subscriptions:
```swift
let active = await PurchasesManager.shared.activeSubscriptions()
```
Select the best (latest-expiring) subscription in a group:
```swift
if let subscription = await PurchasesManager.shared.activeSubscription(inGroup: "com.myapp.subscriptions.premium") {
    print("Active plan:", subscription.displayName)
}
```

Where to get groupID?
It’s available on the product as
StoreProduct/subscriptionGroupID (derived from Product.subscription.subscriptionGroupID) and configured in App Store Connect.

See: ``PurchasesManager/activeSubscriptions()``, ``PurchasesManager/activeSubscription(inGroup:)``,
``StoreProduct/subscriptionGroupID``.
---
## 8  Testing & mocking

Depend on PurchasesProtocol in your app code and inject a mock in tests:
```swift
struct PurchasesMock: PurchasesProtocol {
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [] }
    func purchase(productID: String) async throws -> StoreProduct { throw PurchasesError.purchaseCancelled }
    func restore() async throws { }
    func hasEntitlement(for productID: String) async -> Bool { productID == "com.myapp.pro" }
    func entitlementProductIDs() async -> Set<String> { ["com.myapp.pro"] }
    func activeSubscriptions() async -> [StoreProduct] { [] }
    func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
}
```
---
## 9  Concurrency notes

PurchasesManager is an actor, so its API is thread-safe by design.
Update UI on the main actor when reacting to events.
---
## Next steps

* Browse Quick Help in Xcode or open the full API map:
  <doc:PurchasesManager>.
* For unit tests, depend on ``PurchasesProtocol`` instead of the concrete manager.
* Check **Overview** for feature list and platform requirements.

Happy shipping 🚀

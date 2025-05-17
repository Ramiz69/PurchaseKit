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
    "com.myapp.consumable.coin"
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
## Next steps

* Browse Quick Help in Xcode or open the full API map:
  <doc:PurchasesManager>.
* For unit tests, depend on ``PurchasesProtocol`` instead of the concrete manager.
* Check **Overview** for feature list and platform requirements.

Happy shipping 🚀

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
    let (product, transaction) = try await PurchasesManager.shared
                        .purchase(productID: "com.myapp.pro")
    print("🎉 Purchased:", product.displayName, "transaction", transaction.id)
} catch PurchasesError.purchaseCancelled {
    // user tapped “Cancel” – usually no error UI needed
} catch {
    // handle / log other errors
}
```

The call throws ``PurchasesError``, whose ``PurchasesError/code`` names the failure, including
StoreKit's own such as ``PurchasesError/Code/networkUnavailable``. Match a code in a `catch`
clause as above, or bind the error and compare its code:
`catch let error as PurchasesError where error.code == .purchasePending`.

To buy for an account, buy several units, or apply an offer, pass ``PurchaseOptions``:

```swift
let options = PurchaseOptions(appAccountToken: user.id, quantity: 3)
let result = try await PurchasesManager.shared
    .purchase(productID: "com.myapp.consumable.coin", options: options)
```

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

Read the renewal state - grace period, billing retry, what it renews into:
```swift
if let status = try await PurchasesManager.shared
    .subscriptionStatus(inGroup: "com.myapp.subscriptions.premium"),
   status.state == .inGracePeriod {
    // ask the customer to update their payment method
}
```

<doc:Subscriptions> covers status, intro-offer eligibility, promotional and win-back offers.

---
## 7½  Server-verified consumables <a id="server-verified"></a>

When your **server** credits a purchase to an account - coins, tokens, credits - the device
must not finish the transaction before the server has accepted it. A finished consumable is
never redelivered, so finishing first and then losing the request to your server leaves the
customer charged with nothing to show for it.

Configure manual finishing and buy for the signed-in account:

```swift
PurchasesManager.configure(identifiers: ["com.myapp.coins.100"], finishing: .manual)

let (_, transaction) = try await PurchasesManager.shared
    .purchase(productID: "com.myapp.coins.100", appAccountToken: user.id)

try await api.creditPurchase(signed: transaction.jwsRepresentation!) // your server verifies the JWS
await PurchasesManager.shared.finish(transaction)                    // only after it accepted
```

Purchases that complete outside the call - Ask to Buy approvals, pending payments, the
unfinished ones replayed at launch - arrive through ``PurchasesManager/transactionUpdates``.
Handle them the same way, and drain ``PurchasesManager/unfinishedTransactions()`` at launch
and after sign-in so nothing a previous run missed is left behind. Mock the whole flow
through ``ServerVerifiedPurchasesProtocol``.

---
## 8  Testing & mocking

Depend on PurchasesProtocol in your app code and inject a mock in tests:
```swift
struct PurchasesMock: PurchasesProtocol {
    func requestProducts(includingCache: Bool) async throws -> [StoreProduct] { [] }
    func purchase(
        productID: String,
        options: PurchaseOptions
    ) async throws -> (product: StoreProduct, transaction: StoreTransaction) {
        throw PurchasesError(.purchaseCancelled)
    }
    func restore() async throws { }
    func hasEntitlement(for productID: String) async -> Bool { productID == "com.myapp.pro" }
    func entitlementProductIDs() async -> Set<String> { ["com.myapp.pro"] }
    func activeSubscriptions() async -> [StoreProduct] { [] }
    func activeSubscription(inGroup groupID: String) async -> StoreProduct? { nil }
    func subscriptionStatuses(inGroup groupID: String) async throws -> [StoreSubscriptionStatus] { [] }
    func isEligibleForIntroOffer(inGroup groupID: String) async -> Bool { true }
    func appPurchaseInfo() async throws -> AppPurchaseInfo { throw PurchasesError(.unsupported) }
}
```
`purchase(productID:)` is not a requirement: it calls `purchase(productID:options:)` with
``PurchaseOptions/none``, so the mock above answers both.
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
* Upgrading from 3.x? Read <doc:MigratingTo4>.

Happy shipping 🚀

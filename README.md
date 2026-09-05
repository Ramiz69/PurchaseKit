# RKPurchaseKit

[![Swift](https://img.shields.io/badge/swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2026%20%7C%20macOS%2026%20%7C%20watchOS%2026%20%7C%20tvOS%2026%20%7C%20visionOS%2026-blue)]()

A lightweight Swift framework for in-app purchases using StoreKit 2  
with full support for Swift Concurrency, async/await, and SPM.

## 📦 Installation

### Swift Package Manager

Add this URL to your Xcode project:

```text
https://github.com/Ramiz69/PurchaseKit.git
```
In Package.swift:
```text
.package(url: "https://github.com/Ramiz69/PurchaseKit.git", from: "2.0.0")
```

### ✅ Features
-	async/await API
- actor-based PurchasesManager
- DocC documentation
- Static linking support (type: .static)
- Support for iOS, macOS, tvOS, watchOS, visionOS (26 and later)

### ⚠️ Migrating to 2.0

2.0 raises the deployment target and changes several public types. If you are on 1.x:

- **Platforms** now start at iOS/macOS/tvOS/watchOS/visionOS **26**. Earlier releases are no longer supported; stay on 1.0.6 if you need them.
- **`StoreProduct.product` is now optional.** It is `nil` on values you build yourself, because `StoreKit.Product` cannot be constructed outside StoreKit. There is now a public initializer taking the fields directly, so `PurchasesProtocol` can finally be mocked in tests and previews.
- **`ProductType` gained `unknown`** and `PurchasesError` gained `unhandledPurchaseResult`. Exhaustive `switch` statements over either need a new branch. A StoreKit product type this SDK does not recognise now reports `unknown` instead of silently passing as `nonConsumable`.
- **`purchasedProducts` no longer replays past events.** Every access returns a fresh stream, so several observers can watch at once — previously two `for await` loops split the events between them and each missed the rest. Read current state with `hasEntitlement(for:)` or `requestProducts(includingCache:)` when a subscriber starts.
- **`requestProducts()` with no arguments** is now a distinct overload on `PurchasesProtocol`. Calls are unchanged; only a conformer that relied on the default implementation is affected, and that case no longer compiles rather than recursing forever at runtime.
- `PurchasesError` now conforms to `Equatable` and `LocalizedError`, and `PurchasesManager.resolved()` returns the singleton by throwing `notConfigured` instead of trapping like `shared`.

### 📚 Documentation

- 🧭 [Online documentation →](https://ramiz69.github.io/PurchaseKit)
- 🛠 In Xcode: `Product > Build Documentation`

### 📄 License

```text
MIT © Ramiz Kichibekov
```

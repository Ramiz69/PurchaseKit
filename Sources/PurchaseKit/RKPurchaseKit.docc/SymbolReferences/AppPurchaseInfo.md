# ``AppPurchaseInfo``

How and when the customer got the app itself, read from StoreKit's `AppTransaction`.

## Overview

Use it to reward customers who paid for the app before it moved to in-app purchases:
``originalAppVersion`` is the version they first downloaded.

```swift
let info = try await PurchasesManager.shared.appPurchaseInfo()
if info.originalAppVersion.compare("2.0", options: .numeric) == .orderedAscending {
    unlockLegacyPro()
}
```

On iOS and visionOS, ``originalAppVersion`` and ``appVersion`` are the build number
(`CFBundleVersion`); on macOS they are the marketing version (`CFBundleShortVersionString`).
In the sandbox the original version is always `"1.0"`.

Send ``jwsRepresentation`` to your server when the decision should not rest on the device.

## Topics

### Purchase
- ``originalAppVersion``
- ``originalPurchaseDate``
- ``appVersion``

### Environment
- ``environment``

### Server verification
- ``jwsRepresentation``

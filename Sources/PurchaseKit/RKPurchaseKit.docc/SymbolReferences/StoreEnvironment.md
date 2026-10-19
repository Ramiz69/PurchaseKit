# ``StoreEnvironment``

The App Store environment a transaction or app purchase came from.

## Overview

- ``production`` – the live App Store.
- ``sandbox`` – TestFlight and sandbox accounts.
- ``xcode`` – a local StoreKit configuration file in Xcode.

Read it from ``StoreTransaction/environment`` and ``AppPurchaseInfo/environment``. A server
that receives a signed transaction should route it to the matching App Store Server API
environment.

`StoreEnvironment` is a `RawRepresentable` struct, not an enum, so an environment a future
StoreKit adds is still representable. Compare with `==`.

## Topics

### Environments
- ``production``
- ``sandbox``
- ``xcode``

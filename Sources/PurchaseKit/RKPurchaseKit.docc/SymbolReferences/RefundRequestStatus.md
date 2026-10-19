# ``RefundRequestStatus``

How the customer left the refund sheet.

## Overview

Returned by the manager's `beginRefundRequest(for:in:)` on iOS and visionOS.

- ``success`` – the customer submitted a request. It does not mean the refund was granted:
  the App Store decides later, and a granted refund arrives as a revoked transaction through
  ``PurchasesManager/transactionUpdates`` with ``StoreTransaction/revocationDate`` set.
- ``userCancelled`` – the customer closed the sheet without submitting.

## Topics

### Outcomes
- ``success``
- ``userCancelled``

# ``FinishPolicy``

Who finishes StoreKit transactions: the kit, as soon as it sees them, or your app, after its
server has accepted them.

Finishing a consumable removes it from `Transaction.unfinished` for good. Use
``FinishPolicy/manual`` whenever a server credits the purchase, so a lost request costs a
retry instead of the customer's money.

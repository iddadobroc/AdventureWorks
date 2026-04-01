# AdventureWorks

SQL project to combine all the commits of our beloved TEAM


Problems on going

  -When creating Auction the default bid value has to be set considering the FLAG. (At the moment if we don't declare it it will be set to zero the initial bid price)

Problems i've (Allcaide) noticed related to bid system. Still to be solved
    1. InitialBidPrice may be zero
    Auctions can be created without explicitly setting InitialBidPrice, causing bids to start from 0.
    This breaks the minimum bid logic and violates the intended auction rules.
    2. Maximum bid can be lower than the minimum allowed bid
    MaximumBidLimit * ListPrice can be lower than InitialBidPrice + Increment.
    This creates an auction state where no valid bid is mathematically possible.
    3. Missing validation for maxbid >= minnext
    There is no explicit check ensuring the maximum allowed bid is not below the minimum next bid.
    This allows logically inconsistent auctions to accept bids.
    4. Bid value can become invalid after applying the cap
    A bid may pass the minimum check and then be reduced by the maximum cap.
    The final inserted bid can end up below the required minimum.
    5. Auctions at maximum price still accept bids
    When the current bid has already reached the maximum allowed value, bids are still processed.
    This leads to inconsistent auction states where no further bidding should be possible.
    6. ExpireDate is ignored during bidding
    The bidding procedure does not check whether the auction has already expired.
    This allows bids to be placed outside the valid auction time window.
    7. AuctionStatus validation is too weak
    Only the string value 'Active' is checked, without enforcing consistency.
    Cancelled or duplicated active auctions may still receive bids.
    8. Multiple active auctions per product are possible
    There is no guarantee that only one active auction exists per ProductID.
    Bids may be placed against an arbitrary auction instance.
    9. Threshold configuration is not guaranteed to be unique
    The threshold table may contain multiple rows, but bidding logic selects one arbitrarily.
    This causes inconsistent increment and maximum bid rules across bids.
    10. CustomerID model is inconsistent with bidding logic
    Bids reference Person.Person instead of Sales.Customer.
    This allows bids from entities that are not valid customers in the sales model.

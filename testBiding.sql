USE AdventureWorks;
GO

/*
TEST SETUP (portal-friendly, no fallback creation)
Purpose:
- Select an existing ACTIVE auction and use its ProductID for bidding tests.
- Select a valid CustomerID to simulate a bidder.
- Output a single debug row via SELECT (reliable in Azure Portal Query Editor).
*/

DECLARE @TestProductID INT;
DECLARE @TestCustomerID INT;
DECLARE @AuctionID INT;

-- 1) Pick an existing ACTIVE auction (the natural starting point for bid testing)
SELECT TOP (1)
    @AuctionID = AuctionID,
    @TestProductID = ProductID
FROM Auction.Auction
WHERE AuctionStatus = 'Active'
ORDER BY ListedDate DESC;

-- 2) Pick a CustomerID to simulate a bidder
SELECT TOP (1) @TestCustomerID = CustomerID
FROM Sales.Customer
ORDER BY CustomerID;

-- 3) Debug output (shows under Results in Azure portal)
--    If no active auction exists, @AuctionID will be NULL and this will make it obvious.
SELECT CONCAT(
        'Test ProductID = ', COALESCE(CONVERT(varchar(20), @TestProductID), 'NULL'),
        ' | Test CustomerID = ', COALESCE(CONVERT(varchar(20), @TestCustomerID), 'NULL'),
        ' | Active AuctionID = ', COALESCE(CONVERT(varchar(20), @AuctionID), 'NULL')
    ) AS DebugMessage; --only way to test and see the print on cloud azure lol xD

GO
``
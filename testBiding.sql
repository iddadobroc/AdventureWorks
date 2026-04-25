CREATE OR ALTER PROCEDURE Auction.uspTryBidProduct(
    @ProductID INT,
    @CustomerID INT,
    @BidAmount MONEY = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @ActiveAuction INT;
        DECLARE @ExpireDate DATETIME2(0);

        DECLARE @inc MONEY;
        DECLARE @maxmult DECIMAL(10,4);
        DECLARE @listprice MONEY;
        DECLARE @maxbid MONEY;

        DECLARE @current MONEY;
        DECLARE @minnext MONEY;

        -- Get threshold configuration
        SELECT TOP 1
            @inc = Increment,
            @maxmult = MaximumBidLimit
        FROM Auction.Threshold;

        IF @inc IS NULL OR @maxmult IS NULL
            THROW 50010, 'Threshold configuration missing in Auction.Threshold.', 1;

        -- Get product list price 
        SELECT @listprice = ListPrice
        FROM Auction.Product
        WHERE ProductID = @ProductID;

        IF @listprice IS NULL
            THROW 50011, 'Invalid ProductID (not found in Auction.Product).', 1;

        SET @maxbid = @maxmult * @listprice;

        BEGIN TRAN;

        -- Lock the active auction row (concurrency proof with WITH(UPDLOCK, HOLDLOCK)
        SELECT TOP (1)
            @ActiveAuction = AuctionID,
            @ExpireDate = ExpireDate
        FROM Auction.Auction WITH (UPDLOCK, HOLDLOCK)
        WHERE ProductID = @ProductID
          AND AuctionStatus = 'Active'
        ORDER BY AuctionID DESC;

        IF @ActiveAuction IS NULL
            THROW 50003, 'No active auction for this product.', 1;

        IF @ExpireDate IS NOT NULL AND @ExpireDate <= SYSUTCDATETIME() ---Check if sys utc current datetime is after the expiry date
            THROW 50004, 'Auction expired. No more bids allowed.', 1;

        -- Lock bids for this auction when computing current
        SELECT @current = MAX(BidAmount)
        FROM Auction.Bid WITH (UPDLOCK, HOLDLOCK)
        WHERE AuctionID = @ActiveAuction;

        IF @current IS NULL
        BEGIN
            SELECT @current = InitialBidPrice
            FROM Auction.Auction
            WHERE AuctionID = @ActiveAuction;
        END

        SET @minnext = @current + @inc;

        IF @BidAmount IS NULL
            SET @BidAmount = @minnext;

        IF @BidAmount < @minnext
            THROW 50005, 'Bid too low. Must be at least current + increment.', 1;

        IF @BidAmount > @maxbid
            SET @BidAmount = @maxbid;

        INSERT INTO Auction.Bid (AuctionID, CustomerID, BidAmount)
        VALUES (@ActiveAuction, @CustomerID, @BidAmount);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- TEST 1, Purpose: Verify that a product can be successfully added to an auction, Expected result: One ACTIVE auction row created for ProductID = 707
-- Check if upsAddProductToAuction works, ExpireDate default is calculated and AuctionStatus is "Active" :)

EXEC Auction.uspAddProductToAuction
    @ProductID = 707;

SELECT *
FROM Auction.Auction
WHERE ProductID = 707;
``
-- TEST 2
-- Purpose: Place the FIRST bid using NULL BidAmount
-- Expected result: BidAmount is automatically set to (InitialBidPrice + Increment)
-- Checks rule: If BidAmount is NULL -> current + increment

EXEC Auction.uspTryBidProduct
    @ProductID = 707,
    @CustomerID = 3,
    @BidAmount = NULL;

SELECT *
FROM Auction.Bid
WHERE AuctionID = (
    SELECT AuctionID
    FROM Auction.Auction
    WHERE ProductID = 707
      AND AuctionStatus = 'Active'
);
-- TEST 3
-- Purpose: Try to place a bid LOWER than the minimum allowed increment
-- Expected result: Procedure fails with error "Bid too low"
-- Checks rule: Bid must be at least (current bid + increment)

DECLARE @CurrentBid MONEY;

SELECT @CurrentBid = MAX(BidAmount)
FROM Auction.Bid
WHERE AuctionID = (
    SELECT AuctionID
    FROM Auction.Auction
    WHERE ProductID = 707
      AND AuctionStatus = 'Active'
);

EXEC Auction.uspTryBidProduct
    @ProductID = 707,
    @CustomerID = 3,
    @BidAmount = @CurrentBid;  -- intentionally invalid (no increment)

-- TEST 4
-- Purpose: Try to place a bid ABOVE the maximum allowed limit
-- Expected result: BidAmount is capped to (MaximumBidLimit * ListPrice)
-- Checks maximum bid enforcement via Auction.Threshold configuration

EXEC Auction.uspTryBidProduct
    @ProductID = 707,
    @CustomerID = 3,
    @BidAmount = 999999;  -- intentionally excessive

SELECT TOP 1 *
FROM Auction.Bid
WHERE AuctionID = (
    SELECT AuctionID
    FROM Auction.Auction
    WHERE ProductID = 707
      AND AuctionStatus = 'Active'
)
ORDER BY BidDate DESC;

-- TEST 5
-- Purpose: Ensure bids are rejected AFTER auction expiration
-- Expected result: Procedure fails with "Auction expired. No more bids allowed"
-- Checks expiration logic protection

-- Force auction to be expired
UPDATE Auction.Auction
SET ExpireDate = DATEADD(MINUTE, -1, SYSUTCDATETIME())
WHERE ProductID = 707
  AND AuctionStatus = 'Active';

EXEC Auction.uspTryBidProduct
    @ProductID = 707,
    @CustomerID = 3,
    @BidAmount = NULL;


-- TEST 6
-- Purpose: Close expired auctions and assign winning customer
-- Expected result:
--   - AuctionStatus changes to CLOSED (or equivalent)
--   - WinningCustomerID is populated with last/highest bidder
-- Checks uspUpdateProductAuctionStatus business logic

EXEC Auction.uspUpdateProductAuctionStatus;

SELECT
    AuctionID,
    ProductID,
    AuctionStatus,
    WinningCustomerID,
    ExpireDate
FROM Auction.Auction
WHERE ProductID = 707;

-- CLEANUP
-- Purpose: Remove test auction and bids For re run the tests

DELETE FROM Auction.Bid
WHERE AuctionID IN (
    SELECT AuctionID FROM Auction.Auction WHERE ProductID = 707
);

DELETE FROM Auction.Auction
WHERE ProductID = 707;

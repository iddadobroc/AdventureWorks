/*SELECT TOP 1 ProductID, ListPrice
FROM Auction.Product;

INSERT INTO Auction.Auction (ProductID,  ExpireDate)
VALUES (707,  DATEADD(day, 7, GETUTCDATE()));
;

SELECT *
FROM Auction.Auction;


--Insert manually a new product to test biding
*/


CREATE OR ALTER PROCEDURE Auction.uspTryBidProduct(
    @ProductID INT,
    @CustomerID INT,
    @BidAmount MONEY = NULL
)
AS
BEGIN
    -- This stored procedure adds a bid on behalf of a customer
    -- Rules:
    -- - If BidAmount is NULL -> bid = current + increment
    -- - Bid must be at least current + increment
    -- - Bid cannot exceed MaximumBidLimit * ListPrice

    DECLARE @ActiveAuction INT;

    SELECT @ActiveAuction = AuctionID
    FROM Auction.Auction
    WHERE ProductID = @ProductID
      AND AuctionStatus = 'Active';

    IF @ActiveAuction IS NULL
    BEGIN
        RAISERROR('No active auction for this product.', 16, 1);
        RETURN;
    END

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

    -- Get product list price
    SELECT @listprice = ListPrice
    FROM Auction.Product
    WHERE ProductID = @ProductID;

    SET @maxbid = @maxmult * @listprice;

    -- Get current bid (or initial bid if no bids yet)
    SELECT @current = MAX(BidAmount)
    FROM Auction.Bid
    WHERE AuctionID = @ActiveAuction;

    IF @current IS NULL
    BEGIN
        SELECT @current = InitialBidPrice
        FROM Auction.Auction
        WHERE AuctionID = @ActiveAuction;
    END

    SET @minnext = @current + @inc;

    -- If BidAmount is NULL, place minimum valid bid
    IF @BidAmount IS NULL
    BEGIN
        SET @BidAmount = @minnext;
    END

    -- Validate minimum bid FIRST
    IF @BidAmount < @minnext
    BEGIN
        RAISERROR('Bid too low. Must be at least current + increment.', 16, 1);
        RETURN;
    END

    -- Apply maximum bid limit
    IF @BidAmount > @maxbid
    BEGIN
        SET @BidAmount = @maxbid;
    END

    INSERT INTO Auction.Bid
        (AuctionID, CustomerID, BidAmount)
    VALUES
        (@ActiveAuction, @CustomerID, @BidAmount);
END
GO

/*
EXEC Auction.uspTryBidProduct
    @ProductID = 707,
    @CustomerID = 3,
    @BidAmount = 620;

SELECT ProductID, ListPrice
FROM Auction.Product
WHERE ProductID = 707;

*/

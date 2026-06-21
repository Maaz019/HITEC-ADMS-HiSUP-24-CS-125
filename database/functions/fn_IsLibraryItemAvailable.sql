-- ============================================================
-- fn_IsLibraryItemAvailable
-- Scalar UDF: returns 1 if at least one copy of a library item
-- is currently available to issue, 0 otherwise.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER FUNCTION fn_IsLibraryItemAvailable (@ItemID INT)
RETURNS BIT
AS
BEGIN
    DECLARE @AvailableCopies INT;
    DECLARE @IsAvailable BIT;

    SELECT @AvailableCopies = AvailableCopies
    FROM LibraryItems
    WHERE ItemID = @ItemID;

    SET @IsAvailable = CASE
        WHEN @AvailableCopies IS NULL THEN 0  -- item doesn't exist
        WHEN @AvailableCopies > 0 THEN 1
        ELSE 0
    END;

    RETURN @IsAvailable;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT ItemID, Title, AvailableCopies, dbo.fn_IsLibraryItemAvailable(ItemID) AS IsAvailable
FROM LibraryItems;
GO

SELECT dbo.fn_IsLibraryItemAvailable(9999) AS NonExistentItem;  -- should return 0
GO

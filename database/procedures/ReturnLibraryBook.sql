-- ============================================================
-- ReturnLibraryBook
-- Processes the return of a library item, calculates fine if overdue.
-- Demonstrates: TRY/CATCH, transaction, date-based fine calculation
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE ReturnLibraryBook
    @IssueID        INT,
    @FinePerDay      DECIMAL(8,2) = 10.00
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM LibraryIssues WHERE IssueID = @IssueID)
    BEGIN
        RAISERROR('IssueID %d does not exist.', 16, 1, @IssueID);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM LibraryIssues WHERE IssueID = @IssueID AND ReturnDate IS NOT NULL)
    BEGIN
        RAISERROR('This item has already been returned.', 16, 1);
        RETURN;
    END

    -- ---- Calculate fine if overdue ----
    DECLARE @DueDate DATE, @ItemID INT;
    DECLARE @ReturnDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @DaysLate INT;
    DECLARE @FineAmount DECIMAL(8,2) = 0;

    SELECT @DueDate = DueDate, @ItemID = ItemID
    FROM LibraryIssues
    WHERE IssueID = @IssueID;

    SET @DaysLate = DATEDIFF(DAY, @DueDate, @ReturnDate);

    IF @DaysLate > 0
        SET @FineAmount = @DaysLate * @FinePerDay;

    -- ---- Transaction: record return, restore copy count ----
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE LibraryIssues
        SET ReturnDate = @ReturnDate,
            FineAmount = @FineAmount
        WHERE IssueID = @IssueID;

        UPDATE LibraryItems
        SET AvailableCopies = AvailableCopies + 1
        WHERE ItemID = @ItemID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH

    SELECT @IssueID AS IssueID, @DaysLate AS DaysLate, @FineAmount AS FineAmount;
END;
GO

-- ============================================================
-- Test it - return the book issued in IssueLibraryBook test (on time, no fine)
-- ============================================================
DECLARE @TestIssueID INT = (SELECT TOP 1 IssueID FROM LibraryIssues WHERE ItemID = 2 AND ReturnDate IS NULL ORDER BY IssueID DESC);

EXEC ReturnLibraryBook @IssueID = @TestIssueID;
GO

SELECT * FROM LibraryIssues WHERE ItemID = 2 ORDER BY IssueID DESC;
SELECT ItemID, Title, AvailableCopies FROM LibraryItems WHERE ItemID = 2;
GO

-- ============================================================
-- Test overdue fine calculation using seeded overdue issue
-- (IssueID 2 in seed data: issued 2026-05-20, due 2026-06-03, already returned 2026-06-10)
-- Let's instead test on a fresh overdue scenario
-- ============================================================
DECLARE @NewOverdueIssue INT;

EXEC IssueLibraryBook
    @ItemID = 3,
    @StudentID = 4,
    @DueDate = '2026-06-15',  -- already in the past relative to today (assume today >= 2026-06-21)
    @NewIssueID = @NewOverdueIssue OUTPUT;

EXEC ReturnLibraryBook @IssueID = @NewOverdueIssue, @FinePerDay = 10.00;
GO

-- ============================================================
-- Test error handling - returning an already-returned item
-- ============================================================
DECLARE @AlreadyReturnedID INT = (SELECT TOP 1 IssueID FROM LibraryIssues WHERE ReturnDate IS NOT NULL);

BEGIN TRY
    EXEC ReturnLibraryBook @IssueID = @AlreadyReturnedID;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

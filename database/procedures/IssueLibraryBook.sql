-- ============================================================
-- IssueLibraryBook
-- Issues a library item to either a student or a faculty member.
-- Demonstrates: TRY/CATCH, transaction with locking, mutually
--               exclusive parameter validation (student XOR faculty)
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE IssueLibraryBook
    @ItemID       INT,
    @StudentID    INT = NULL,
    @FacultyID    INT = NULL,
    @DueDate      DATE,
    @NewIssueID   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM LibraryItems WHERE ItemID = @ItemID)
    BEGIN
        RAISERROR('ItemID %d does not exist.', 16, 1, @ItemID);
        RETURN;
    END

    -- Exactly one of StudentID / FacultyID must be provided
    IF (@StudentID IS NULL AND @FacultyID IS NULL) OR (@StudentID IS NOT NULL AND @FacultyID IS NOT NULL)
    BEGIN
        RAISERROR('Exactly one of StudentID or FacultyID must be provided.', 16, 1);
        RETURN;
    END

    IF @StudentID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    IF @FacultyID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Faculty WHERE FacultyID = @FacultyID)
    BEGIN
        RAISERROR('FacultyID %d does not exist.', 16, 1, @FacultyID);
        RETURN;
    END

    IF @DueDate <= CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR('DueDate must be in the future.', 16, 1);
        RETURN;
    END

    -- ---- Transaction: check availability, then issue ----
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AvailableCopies INT;

        -- Lock the item row while checking availability (same pattern as
        -- seat checking and hostel room checking)
        SELECT @AvailableCopies = AvailableCopies
        FROM LibraryItems WITH (UPDLOCK, HOLDLOCK)
        WHERE ItemID = @ItemID;

        IF @AvailableCopies <= 0
        BEGIN
            RAISERROR('No copies available for this item.', 16, 1);
        END

        INSERT INTO LibraryIssues (ItemID, StudentID, FacultyID, IssueDate, DueDate, ReturnDate, FineAmount)
        VALUES (@ItemID, @StudentID, @FacultyID, GETDATE(), @DueDate, NULL, 0);

        SET @NewIssueID = SCOPE_IDENTITY();

        UPDATE LibraryItems
        SET AvailableCopies = AvailableCopies - 1
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
END;
GO

-- ============================================================
-- Test it - issue a book to a student
-- ============================================================
DECLARE @NewIssue INT;

EXEC IssueLibraryBook
    @ItemID = 2,  -- T-SQL Fundamentals, 3/3 copies available
    @StudentID = 3,
    @DueDate = '2026-07-05',
    @NewIssueID = @NewIssue OUTPUT;

SELECT @NewIssue AS NewIssueID;
SELECT * FROM LibraryIssues WHERE IssueID = @NewIssue;
SELECT ItemID, Title, TotalCopies, AvailableCopies FROM LibraryItems WHERE ItemID = 2;
GO

-- ============================================================
-- Test error handling - both StudentID and FacultyID provided (invalid)
-- ============================================================
DECLARE @NewIssue2 INT;

BEGIN TRY
    EXEC IssueLibraryBook
        @ItemID = 1,
        @StudentID = 1,
        @FacultyID = 1,  -- both provided, should fail
        @DueDate = '2026-07-10',
        @NewIssueID = @NewIssue2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

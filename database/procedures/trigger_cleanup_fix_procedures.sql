-- ============================================================
-- Trigger Cleanup: Remove duplicate manual count updates
-- Run this AFTER all 6 triggers are created.
--
-- Why this is needed: trg_AfterEnrollment and trg_AfterLibraryReturn
-- now automatically update SeatsFilled / AvailableCopies whenever
-- the relevant INSERT/UPDATE happens. EnrollInCourse and
-- ReturnLibraryBook were written BEFORE these triggers existed,
-- so they still contain their own manual UPDATE statements for
-- the same columns. Left as-is, every enrollment or return would
-- increment the count TWICE. This script redefines both
-- procedures with the manual count-update lines removed, since
-- the trigger now owns that responsibility.
-- ============================================================
USE HiSUP_DB;
GO

-- ---- EnrollInCourse: remove manual SeatsFilled update ----
CREATE OR ALTER PROCEDURE EnrollInCourse
    @StudentID      INT,
    @SectionID      INT,
    @NewEnrollmentID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Sections WHERE SectionID = @SectionID)
    BEGIN
        RAISERROR('SectionID %d does not exist.', 16, 1, @SectionID);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM Enrollments
        WHERE StudentID = @StudentID AND SectionID = @SectionID AND Status <> 'Dropped'
    )
    BEGIN
        RAISERROR('This student is already enrolled in this section.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MaxSeats INT, @SeatsFilled INT;

        SELECT @MaxSeats = MaxSeats, @SeatsFilled = SeatsFilled
        FROM Sections WITH (UPDLOCK, HOLDLOCK)
        WHERE SectionID = @SectionID;

        IF @SeatsFilled >= @MaxSeats
        BEGIN
            RAISERROR('No seats available in this section (%d/%d filled).', 16, 1, @SeatsFilled, @MaxSeats);
        END

        -- trg_PreventDuplicateEnrollment (INSTEAD OF) will validate and
        -- perform this insert; trg_AfterEnrollment will then update
        -- SeatsFilled automatically - no manual UPDATE needed here anymore
        INSERT INTO Enrollments (StudentID, SectionID, Status)
        VALUES (@StudentID, @SectionID, 'Enrolled');

        SET @NewEnrollmentID = SCOPE_IDENTITY();

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

-- ---- ReturnLibraryBook: remove manual AvailableCopies update ----
CREATE OR ALTER PROCEDURE ReturnLibraryBook
    @IssueID        INT,
    @FinePerDay      DECIMAL(8,2) = 10.00
AS
BEGIN
    SET NOCOUNT ON;

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

    BEGIN TRY
        BEGIN TRANSACTION;

        -- trg_AfterLibraryReturn will automatically increment
        -- AvailableCopies when it sees ReturnDate go from NULL to
        -- a real date - no manual UPDATE LibraryItems needed here anymore
        UPDATE LibraryIssues
        SET ReturnDate = @ReturnDate,
            FineAmount = @FineAmount
        WHERE IssueID = @IssueID;

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

PRINT 'EnrollInCourse and ReturnLibraryBook updated - manual count updates removed, now relying on triggers.';

-- ============================================================
-- EnrollInCourse
-- Enrolls a student into a section, with live seat checking
-- Demonstrates: TRY/CATCH, explicit transaction, RAISERROR/THROW,
--               input validation, seat-count enforcement
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE EnrollInCourse
    @StudentID      INT,
    @SectionID      INT,
    @NewEnrollmentID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
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

    -- ---- Transaction: check seats and enroll atomically ----
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Lock the section row while we check seats, to prevent two
        -- concurrent enrollments both seeing a "free seat" and over-filling it
        DECLARE @MaxSeats INT, @SeatsFilled INT;

        SELECT @MaxSeats = MaxSeats, @SeatsFilled = SeatsFilled
        FROM Sections WITH (UPDLOCK, HOLDLOCK)
        WHERE SectionID = @SectionID;

        IF @SeatsFilled >= @MaxSeats
        BEGIN
            RAISERROR('No seats available in this section (%d/%d filled).', 16, 1, @SeatsFilled, @MaxSeats);
        END

        INSERT INTO Enrollments (StudentID, SectionID, Status)
        VALUES (@StudentID, @SectionID, 'Enrolled');

        SET @NewEnrollmentID = SCOPE_IDENTITY();

        UPDATE Sections
        SET SeatsFilled = SeatsFilled + 1
        WHERE SectionID = @SectionID;

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
-- Test it - enroll the student we created in RegisterStudent
-- ============================================================
DECLARE @NewEnrollID INT;
DECLARE @TestStudentID INT = (SELECT StudentID FROM Students WHERE RegistrationNo = '24-CS-130');
DECLARE @TestSectionID INT = (SELECT SectionID FROM Sections WHERE SectionCode = 'B');

EXEC EnrollInCourse
    @StudentID = @TestStudentID,
    @SectionID = @TestSectionID,
    @NewEnrollmentID = @NewEnrollID OUTPUT;

SELECT @NewEnrollID AS NewEnrollmentID;
SELECT * FROM Enrollments WHERE EnrollmentID = @NewEnrollID;
SELECT SectionID, MaxSeats, SeatsFilled FROM Sections WHERE SectionID = @TestSectionID;
GO

-- ============================================================
-- Test duplicate enrollment - should fail
-- ============================================================
DECLARE @NewEnrollID2 INT;
DECLARE @TestStudentID2 INT = (SELECT StudentID FROM Students WHERE RegistrationNo = '24-CS-130');
DECLARE @TestSectionID2 INT = (SELECT SectionID FROM Sections WHERE SectionCode = 'B');

BEGIN TRY
    EXEC EnrollInCourse
        @StudentID = @TestStudentID2,
        @SectionID = @TestSectionID2,
        @NewEnrollmentID = @NewEnrollID2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- MarkAttendance
-- Records attendance for one student in one section on a given date.
-- If attendance was already marked for that day, updates it instead
-- of failing (a faculty member correcting a mistake is a normal case).
-- Demonstrates: TRY/CATCH, transaction, UNIQUE constraint handling,
--               upsert logic
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE MarkAttendance
    @EnrollmentID     INT,
    @AttendanceDate   DATE,
    @Status           NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE EnrollmentID = @EnrollmentID)
    BEGIN
        RAISERROR('EnrollmentID %d does not exist.', 16, 1, @EnrollmentID);
        RETURN;
    END

    IF @Status NOT IN ('Present', 'Absent', 'Leave')
    BEGIN
        RAISERROR('Status must be Present, Absent, or Leave.', 16, 1);
        RETURN;
    END

    IF @AttendanceDate > CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR('Cannot mark attendance for a future date.', 16, 1);
        RETURN;
    END

    -- ---- Transaction: upsert ----
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM AttendanceRecords
            WHERE EnrollmentID = @EnrollmentID AND AttendanceDate = @AttendanceDate
        )
        BEGIN
            UPDATE AttendanceRecords
            SET Status = @Status
            WHERE EnrollmentID = @EnrollmentID AND AttendanceDate = @AttendanceDate;
        END
        ELSE
        BEGIN
            INSERT INTO AttendanceRecords (EnrollmentID, AttendanceDate, Status)
            VALUES (@EnrollmentID, @AttendanceDate, @Status);
        END

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
-- Test it - mark attendance for a new date
-- ============================================================
EXEC MarkAttendance @EnrollmentID = 1, @AttendanceDate = '2026-06-15', @Status = 'Present';
GO

SELECT * FROM AttendanceRecords WHERE EnrollmentID = 1 ORDER BY AttendanceDate;
GO

-- ============================================================
-- Test the upsert - re-mark the same day with a different status
-- (should UPDATE the existing row, not fail or duplicate)
-- ============================================================
EXEC MarkAttendance @EnrollmentID = 1, @AttendanceDate = '2026-06-15', @Status = 'Absent';
GO

SELECT * FROM AttendanceRecords WHERE EnrollmentID = 1 ORDER BY AttendanceDate;
GO

-- ============================================================
-- Test error handling - invalid status
-- ============================================================
BEGIN TRY
    EXEC MarkAttendance @EnrollmentID = 1, @AttendanceDate = '2026-06-16', @Status = 'Maybe';
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

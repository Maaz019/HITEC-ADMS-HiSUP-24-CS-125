-- ============================================================
-- DEADLOCK SIMULATION - WITH AUDITLOG LOGGING AND RETRY
-- This wraps the lock-order conflict inside a TRY/CATCH that
-- specifically checks for ERROR_NUMBER() = 1205 (the deadlock
-- victim error code), logs it to AuditLog, and retries up to
-- 3 times - the brief's required "deadlock simulation and
-- retry" behavior, built at the database layer (the C# layer
-- will call this same retry pattern later).
--
-- HOW TO RUN THE DEMO:
-- Open TWO separate query tabs.
-- Tab 1: EXEC DeadlockTest_LockStudentsThenSections;
-- Tab 2: EXEC DeadlockTest_LockSectionsThenStudents;
-- Run Tab 1 first, then within ~2 seconds run Tab 2.
-- One of the two will be chosen as the deadlock victim, log a
-- row to AuditLog, retry, and (assuming the other has since
-- committed and released its locks) succeed on retry.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE DeadlockTest_LockStudentsThenSections
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RetryCount INT = 0;
    DECLARE @MaxRetries INT = 3;
    DECLARE @Done BIT = 0;

    WHILE @RetryCount < @MaxRetries AND @Done = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE Students SET CurrentSemester = CurrentSemester WHERE StudentID = 1;

            WAITFOR DELAY '00:00:05';

            UPDATE Sections SET RoomNumber = RoomNumber WHERE SectionID = 1;

            COMMIT TRANSACTION;
            PRINT 'DeadlockTest_LockStudentsThenSections completed successfully.';
            SET @Done = 1;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            IF ERROR_NUMBER() = 1205
            BEGIN
                INSERT INTO AuditLog (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
                VALUES (
                    'Deadlock', 'DEADLOCK_VICTIM', NULL, NULL,
                    'Procedure: DeadlockTest_LockStudentsThenSections, RetryAttempt: ' +
                        CAST(@RetryCount + 1 AS NVARCHAR(5)) + ', ErrorMessage: ' + ERROR_MESSAGE(),
                    SUSER_NAME(), GETDATE()
                );

                SET @RetryCount = @RetryCount + 1;
                PRINT 'Deadlock detected (Error 1205) - logged to AuditLog. Retrying (' +
                    CAST(@RetryCount AS NVARCHAR(5)) + '/' + CAST(@MaxRetries AS NVARCHAR(5)) + ')...';

                IF @RetryCount >= @MaxRetries
                BEGIN
                    RAISERROR('Max retries reached after repeated deadlocks.', 16, 1);
                    RETURN;
                END

                WAITFOR DELAY '00:00:01';
            END
            ELSE
            BEGIN
                DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
                RAISERROR(@ErrMsg, 16, 1);
                RETURN;
            END
        END CATCH
    END
END;
GO

CREATE OR ALTER PROCEDURE DeadlockTest_LockSectionsThenStudents
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RetryCount INT = 0;
    DECLARE @MaxRetries INT = 3;
    DECLARE @Done BIT = 0;

    WHILE @RetryCount < @MaxRetries AND @Done = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE Sections SET RoomNumber = RoomNumber WHERE SectionID = 1;

            WAITFOR DELAY '00:00:02';

            UPDATE Students SET CurrentSemester = CurrentSemester WHERE StudentID = 1;

            COMMIT TRANSACTION;
            PRINT 'DeadlockTest_LockSectionsThenStudents completed successfully.';
            SET @Done = 1;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            IF ERROR_NUMBER() = 1205
            BEGIN
                INSERT INTO AuditLog (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
                VALUES (
                    'Deadlock', 'DEADLOCK_VICTIM', NULL, NULL,
                    'Procedure: DeadlockTest_LockSectionsThenStudents, RetryAttempt: ' +
                        CAST(@RetryCount + 1 AS NVARCHAR(5)) + ', ErrorMessage: ' + ERROR_MESSAGE(),
                    SUSER_NAME(), GETDATE()
                );

                SET @RetryCount = @RetryCount + 1;
                PRINT 'Deadlock detected (Error 1205) - logged to AuditLog. Retrying (' +
                    CAST(@RetryCount AS NVARCHAR(5)) + '/' + CAST(@MaxRetries AS NVARCHAR(5)) + ')...';

                IF @RetryCount >= @MaxRetries
                BEGIN
                    RAISERROR('Max retries reached after repeated deadlocks.', 16, 1);
                    RETURN;
                END

                WAITFOR DELAY '00:00:01';
            END
            ELSE
            BEGIN
                DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
                RAISERROR(@ErrMsg, 16, 1);
                RETURN;
            END
        END CATCH
    END
END;
GO

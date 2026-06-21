-- ============================================================
-- BulkResultUpload
-- Processes a batch of grade entries (simulating a CSV upload).
-- Uses SAVE TRANSACTION so that if one row fails validation,
-- ONLY that row is rolled back - the rest of the batch continues
-- and commits normally. This is the brief's required SAVEPOINT
-- demonstration (Module 4).
--
-- Input is a table-valued parameter: a list of (EnrollmentID,
-- MarksObtained) pairs to process in one call.
-- ============================================================
USE HiSUP_DB;
GO

-- ---- Step 1: Create a table type to hold the batch of rows ----
IF TYPE_ID('dbo.GradeUploadType') IS NULL
BEGIN
    CREATE TYPE dbo.GradeUploadType AS TABLE (
        RowNum         INT,
        EnrollmentID   INT,
        MarksObtained  DECIMAL(5,2)
    );
END
GO

-- ---- Step 2: The procedure itself ----
CREATE OR ALTER PROCEDURE BulkResultUpload
    @GradeBatch dbo.GradeUploadType READONLY
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowNum INT, @EnrollmentID INT, @MarksObtained DECIMAL(5,2);
    DECLARE @SuccessCount INT = 0, @FailCount INT = 0;
    DECLARE @ErrorLog NVARCHAR(MAX) = '';

    BEGIN TRANSACTION;

    DECLARE batch_cursor CURSOR FOR
        SELECT RowNum, EnrollmentID, MarksObtained FROM @GradeBatch ORDER BY RowNum;

    OPEN batch_cursor;
    FETCH NEXT FROM batch_cursor INTO @RowNum, @EnrollmentID, @MarksObtained;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SAVE TRANSACTION RowSavepoint;

        BEGIN TRY
            IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE EnrollmentID = @EnrollmentID)
                THROW 50001, 'EnrollmentID does not exist.', 1;

            IF @MarksObtained < 0 OR @MarksObtained > 100
                THROW 50002, 'MarksObtained out of valid range (0-100).', 1;

            IF EXISTS (SELECT 1 FROM Grades WHERE EnrollmentID = @EnrollmentID)
            BEGIN
                UPDATE Grades
                SET MarksObtained = @MarksObtained,
                    LetterGrade = dbo.fn_GetLetterGrade(@MarksObtained),
                    GradedDate = GETDATE()
                WHERE EnrollmentID = @EnrollmentID;
            END
            ELSE
            BEGIN
                INSERT INTO Grades (EnrollmentID, MarksObtained, LetterGrade, GradedDate)
                VALUES (@EnrollmentID, @MarksObtained, dbo.fn_GetLetterGrade(@MarksObtained), GETDATE());
            END

            SET @SuccessCount = @SuccessCount + 1;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION RowSavepoint;

            SET @FailCount = @FailCount + 1;
            SET @ErrorLog = @ErrorLog + 'Row ' + CAST(@RowNum AS NVARCHAR(10)) +
                ' (EnrollmentID ' + CAST(@EnrollmentID AS NVARCHAR(10)) + '): ' +
                ERROR_MESSAGE() + CHAR(13);
        END CATCH

        FETCH NEXT FROM batch_cursor INTO @RowNum, @EnrollmentID, @MarksObtained;
    END

    CLOSE batch_cursor;
    DEALLOCATE batch_cursor;

    COMMIT TRANSACTION;

    SELECT @SuccessCount AS RowsSucceeded, @FailCount AS RowsFailed, @ErrorLog AS ErrorDetails;
END;
GO

-- ============================================================
-- Test it - a batch with two deliberately bad rows mixed in
-- with valid rows
-- ============================================================
DECLARE @Batch dbo.GradeUploadType;

INSERT INTO @Batch (RowNum, EnrollmentID, MarksObtained) VALUES
(1, 1, 88.00),
(2, 99999, 70.00),
(3, 4, 82.50),
(4, 6, 150.00),
(5, 3, 91.00);

EXEC BulkResultUpload @GradeBatch = @Batch;
GO

SELECT * FROM Grades WHERE EnrollmentID IN (1, 4, 3);
GO

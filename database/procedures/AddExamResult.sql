-- ============================================================
-- AddExamResult
-- Records a grade (marks, letter grade, grade points) for a
-- student's enrollment in a section.
-- Demonstrates: TRY/CATCH, transaction, upsert logic,
--               business-rule-driven letter grade assignment
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE AddExamResult
    @EnrollmentID    INT,
    @MarksObtained   DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE EnrollmentID = @EnrollmentID)
    BEGIN
        RAISERROR('EnrollmentID %d does not exist.', 16, 1, @EnrollmentID);
        RETURN;
    END

    IF @MarksObtained IS NULL OR @MarksObtained < 0 OR @MarksObtained > 100
    BEGIN
        RAISERROR('MarksObtained must be between 0 and 100.', 16, 1);
        RETURN;
    END

    -- ---- Derive letter grade and grade points from marks ----
    -- (This mirrors what fn_GetLetterGrade will formalize as a UDF later)
    DECLARE @LetterGrade NVARCHAR(2);
    DECLARE @GradePoints DECIMAL(3,2);

    SELECT
        @LetterGrade = CASE
            WHEN @MarksObtained >= 90 THEN 'A'
            WHEN @MarksObtained >= 85 THEN 'A-'
            WHEN @MarksObtained >= 80 THEN 'B+'
            WHEN @MarksObtained >= 75 THEN 'B'
            WHEN @MarksObtained >= 70 THEN 'B-'
            WHEN @MarksObtained >= 65 THEN 'C+'
            WHEN @MarksObtained >= 60 THEN 'C'
            WHEN @MarksObtained >= 50 THEN 'D'
            ELSE 'F'
        END,
        @GradePoints = CASE
            WHEN @MarksObtained >= 90 THEN 4.00
            WHEN @MarksObtained >= 85 THEN 3.67
            WHEN @MarksObtained >= 80 THEN 3.33
            WHEN @MarksObtained >= 75 THEN 3.00
            WHEN @MarksObtained >= 70 THEN 2.67
            WHEN @MarksObtained >= 65 THEN 2.33
            WHEN @MarksObtained >= 60 THEN 2.00
            WHEN @MarksObtained >= 50 THEN 1.00
            ELSE 0.00
        END;

    -- ---- Transaction: upsert into Grades ----
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM Grades WHERE EnrollmentID = @EnrollmentID)
        BEGIN
            UPDATE Grades
            SET MarksObtained = @MarksObtained,
                LetterGrade = @LetterGrade,
                GradePoints = @GradePoints,
                GradedDate = GETDATE()
            WHERE EnrollmentID = @EnrollmentID;
        END
        ELSE
        BEGIN
            INSERT INTO Grades (EnrollmentID, MarksObtained, LetterGrade, GradePoints, GradedDate)
            VALUES (@EnrollmentID, @MarksObtained, @LetterGrade, @GradePoints, GETDATE());
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

    SELECT @EnrollmentID AS EnrollmentID, @MarksObtained AS MarksObtained,
           @LetterGrade AS LetterGrade, @GradePoints AS GradePoints;
END;
GO

-- ============================================================
-- Test it - add a grade for an enrollment that has none yet (EnrollmentID 7)
-- ============================================================
EXEC AddExamResult @EnrollmentID = 7, @MarksObtained = 81.50;
GO

SELECT * FROM Grades WHERE EnrollmentID = 7;
GO

-- ============================================================
-- Test the upsert - re-grade the same enrollment (correction scenario)
-- ============================================================
EXEC AddExamResult @EnrollmentID = 7, @MarksObtained = 91.00;
GO

SELECT * FROM Grades WHERE EnrollmentID = 7;
GO

-- ============================================================
-- Test error handling - invalid marks
-- ============================================================
BEGIN TRY
    EXEC AddExamResult @EnrollmentID = 7, @MarksObtained = 150.00;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

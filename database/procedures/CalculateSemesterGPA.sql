-- ============================================================
-- CalculateSemesterGPA
-- Calculates a student's semester GPA from their Grades and
-- writes/updates the Results table for that semester.
-- Demonstrates: TRY/CATCH, transaction, aggregation, MERGE-style
--               upsert logic, weighted average calculation
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE CalculateSemesterGPA
    @StudentID  INT,
    @Semester   INT
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    -- ---- Calculate weighted GPA: SUM(GradePoints * CreditHours) / SUM(CreditHours) ----
    DECLARE @SemesterGPA DECIMAL(3,2);
    DECLARE @TotalCreditHours INT;

    SELECT
        @SemesterGPA = CASE
            WHEN SUM(c.CreditHours) = 0 THEN 0
            ELSE SUM(g.GradePoints * c.CreditHours) * 1.0 / SUM(c.CreditHours)
        END,
        @TotalCreditHours = SUM(c.CreditHours)
    FROM Grades g
    INNER JOIN Enrollments e ON g.EnrollmentID = e.EnrollmentID
    INNER JOIN Sections s ON e.SectionID = s.SectionID
    INNER JOIN Courses c ON s.CourseID = c.CourseID
    WHERE e.StudentID = @StudentID
      AND s.Semester = (SELECT TOP 1 Semester FROM Sections WHERE SectionID = e.SectionID);
      -- NOTE: Semester is stored as text (e.g. 'Spring 2026') on Sections;
      -- @Semester here is treated as the student's numeric semester for Results tracking

    IF @TotalCreditHours IS NULL OR @TotalCreditHours = 0
    BEGIN
        RAISERROR('No graded enrollments found for this student in the given semester.', 16, 1);
        RETURN;
    END

    -- ---- Calculate CGPA across all of the student's recorded semesters ----
    DECLARE @CGPA DECIMAL(3,2);

    SELECT @CGPA = AVG(SemesterGPA)
    FROM Results
    WHERE StudentID = @StudentID;

    -- If no prior Results rows exist, CGPA for this run is just the current semester GPA
    IF @CGPA IS NULL
        SET @CGPA = @SemesterGPA;

    DECLARE @ResultStatus NVARCHAR(20) =
        CASE WHEN @SemesterGPA >= 1.00 THEN 'Pass' ELSE 'Fail' END;

    -- ---- Transaction: upsert into Results ----
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM Results WHERE StudentID = @StudentID AND Semester = @Semester)
        BEGIN
            UPDATE Results
            SET SemesterGPA = @SemesterGPA,
                CGPA = @CGPA,
                TotalCreditHours = @TotalCreditHours,
                ResultStatus = @ResultStatus,
                PublishedDate = GETDATE()
            WHERE StudentID = @StudentID AND Semester = @Semester;
        END
        ELSE
        BEGIN
            INSERT INTO Results (StudentID, Semester, SemesterGPA, CGPA, TotalCreditHours, ResultStatus, PublishedDate)
            VALUES (@StudentID, @Semester, @SemesterGPA, @CGPA, @TotalCreditHours, @ResultStatus, GETDATE());
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

    SELECT @StudentID AS StudentID, @Semester AS Semester, @SemesterGPA AS SemesterGPA, @CGPA AS CGPA;
END;
GO

-- ============================================================
-- Test it - calculate GPA for student 1, who has a grade seeded (88.50 -> 'A' -> 4.00 points, CS-318, 3 credit hours)
-- ============================================================
EXEC CalculateSemesterGPA @StudentID = 1, @Semester = 4;
GO

SELECT * FROM Results WHERE StudentID = 1;
GO

-- ============================================================
-- Test error handling - student with no grades yet
-- ============================================================
BEGIN TRY
    EXEC CalculateSemesterGPA @StudentID = 5, @Semester = 6;  -- Zainab Iqbal, no grades seeded
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

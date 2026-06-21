-- ============================================================
-- GenerateTranscript
-- Returns a student's full academic record: every course taken,
-- grade earned, and semester-level summary - the data needed
-- to render/export a transcript PDF from the application layer.
-- Demonstrates: CTE usage, multi-table JOIN, read-only reporting procedure
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE GenerateTranscript
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    -- ---- Student header info ----
    SELECT
        s.StudentID,
        s.RegistrationNo,
        s.FirstName,
        s.LastName,
        p.ProgramName,
        s.EnrollmentYear,
        s.CurrentSemester
    FROM Students s
    INNER JOIN Programs p ON s.ProgramID = p.ProgramID
    WHERE s.StudentID = @StudentID;

    -- ---- Course-by-course transcript detail ----
    SELECT
        c.CourseCode,
        c.CourseTitle,
        c.CreditHours,
        sec.Semester,
        g.MarksObtained,
        g.LetterGrade,
        g.GradePoints
    FROM Enrollments e
    INNER JOIN Sections sec ON e.SectionID = sec.SectionID
    INNER JOIN Courses c ON sec.CourseID = c.CourseID
    LEFT JOIN Grades g ON g.EnrollmentID = e.EnrollmentID
    WHERE e.StudentID = @StudentID
    ORDER BY sec.Semester, c.CourseCode;

    -- ---- Semester-level summary (from Results table) ----
    SELECT
        Semester,
        SemesterGPA,
        CGPA,
        TotalCreditHours,
        ResultStatus,
        PublishedDate
    FROM Results
    WHERE StudentID = @StudentID
    ORDER BY Semester;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
EXEC GenerateTranscript @StudentID = 1;
GO

-- ============================================================
-- Test error handling - non-existent student
-- ============================================================
BEGIN TRY
    EXEC GenerateTranscript @StudentID = 9999;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

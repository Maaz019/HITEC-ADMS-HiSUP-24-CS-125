-- ============================================================
-- GetFacultyWorkload
-- Returns a faculty member's teaching load: every section they
-- teach, with enrollment counts and credit hour totals.
-- (Window functions like RANK for cross-faculty comparison will
--  be added later in the Advanced SQL module - this procedure
--  gives the per-faculty detail that report will rank against.)
-- Demonstrates: aggregation, GROUP BY, JOIN across Sections/Courses
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE GetFacultyWorkload
    @FacultyID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Faculty WHERE FacultyID = @FacultyID)
    BEGIN
        RAISERROR('FacultyID %d does not exist.', 16, 1, @FacultyID);
        RETURN;
    END

    -- ---- Faculty header ----
    SELECT
        f.FacultyID,
        f.FirstName,
        f.LastName,
        f.Designation,
        d.DeptName
    FROM Faculty f
    INNER JOIN Departments d ON f.DepartmentID = d.DepartmentID
    WHERE f.FacultyID = @FacultyID;

    -- ---- Section-by-section workload detail ----
    SELECT
        sec.SectionID,
        c.CourseCode,
        c.CourseTitle,
        c.CreditHours,
        sec.Semester,
        sec.SectionCode,
        sec.MaxSeats,
        sec.SeatsFilled,
        (SELECT COUNT(*) FROM Enrollments e WHERE e.SectionID = sec.SectionID AND e.Status = 'Enrolled') AS ActiveEnrollments
    FROM Sections sec
    INNER JOIN Courses c ON sec.CourseID = c.CourseID
    WHERE sec.FacultyID = @FacultyID
    ORDER BY sec.Semester, c.CourseCode;

    -- ---- Total workload summary ----
    SELECT
        COUNT(DISTINCT sec.SectionID) AS TotalSections,
        SUM(c.CreditHours) AS TotalCreditHoursTaught,
        SUM(sec.SeatsFilled) AS TotalStudentsTaught
    FROM Sections sec
    INNER JOIN Courses c ON sec.CourseID = c.CourseID
    WHERE sec.FacultyID = @FacultyID;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
EXEC GetFacultyWorkload @FacultyID = 1;
GO

EXEC GetFacultyWorkload @FacultyID = 2;
GO

-- ============================================================
-- Test error handling - non-existent faculty
-- ============================================================
BEGIN TRY
    EXEC GetFacultyWorkload @FacultyID = 9999;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

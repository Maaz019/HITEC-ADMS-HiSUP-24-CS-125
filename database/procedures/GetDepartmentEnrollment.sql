-- ============================================================
-- GetDepartmentEnrollment
-- Returns enrollment statistics for a department: student count,
-- program breakdown, and course/section counts.
-- Demonstrates: multi-level aggregation, GROUP BY, JOIN across
--               Departments/Programs/Students
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE GetDepartmentEnrollment
    @DepartmentID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Departments WHERE DepartmentID = @DepartmentID)
    BEGIN
        RAISERROR('DepartmentID %d does not exist.', 16, 1, @DepartmentID);
        RETURN;
    END

    -- ---- Department header ----
    SELECT DepartmentID, DeptName, DeptCode, EstablishedYear
    FROM Departments
    WHERE DepartmentID = @DepartmentID;

    -- ---- Enrollment by program within this department ----
    SELECT
        p.ProgramID,
        p.ProgramName,
        p.DegreeLevel,
        COUNT(s.StudentID) AS StudentCount
    FROM Programs p
    LEFT JOIN Students s ON s.ProgramID = p.ProgramID AND s.Status = 'Active'
    WHERE p.DepartmentID = @DepartmentID
    GROUP BY p.ProgramID, p.ProgramName, p.DegreeLevel
    ORDER BY p.ProgramName;

    -- ---- Course and section counts for this department ----
    SELECT
        COUNT(DISTINCT c.CourseID) AS TotalCourses,
        COUNT(DISTINCT sec.SectionID) AS TotalSectionsOffered,
        COUNT(DISTINCT f.FacultyID) AS TotalFacultyTeaching
    FROM Courses c
    LEFT JOIN Sections sec ON sec.CourseID = c.CourseID
    LEFT JOIN Faculty f ON sec.FacultyID = f.FacultyID
    WHERE c.DepartmentID = @DepartmentID;

    -- ---- Total active students in this department (across all its programs) ----
    SELECT COUNT(*) AS TotalActiveStudents
    FROM Students s
    INNER JOIN Programs p ON s.ProgramID = p.ProgramID
    WHERE p.DepartmentID = @DepartmentID AND s.Status = 'Active';
END;
GO

-- ============================================================
-- Test it
-- ============================================================
EXEC GetDepartmentEnrollment @DepartmentID = 1;  -- Computer Science
GO

-- ============================================================
-- Test error handling - non-existent department
-- ============================================================
BEGIN TRY
    EXEC GetDepartmentEnrollment @DepartmentID = 9999;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- SearchCourses
-- Flexible course search by code, title keyword, department,
-- or credit hours - any combination of filters can be NULL
-- (meaning "don't filter on this").
-- NOTE: This uses static parameterized SQL for now. The brief's
-- Module 6 requires the *advanced* search/filter page to use
-- sp_executesql with dynamic SQL - that version will be built
-- separately when we reach Advanced SQL. This procedure is the
-- simpler baseline search used elsewhere in the app.
-- Demonstrates: optional filter pattern, parameterized safety
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE SearchCourses
    @CourseCode    NVARCHAR(10) = NULL,
    @TitleKeyword  NVARCHAR(100) = NULL,
    @DepartmentID  INT = NULL,
    @MinCreditHours INT = NULL,
    @MaxCreditHours INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.CourseID,
        c.CourseCode,
        c.CourseTitle,
        c.CreditHours,
        d.DeptName,
        pc.CourseCode AS PrerequisiteCode
    FROM Courses c
    INNER JOIN Departments d ON c.DepartmentID = d.DepartmentID
    LEFT JOIN Courses pc ON c.PrerequisiteCourseID = pc.CourseID
    WHERE (@CourseCode IS NULL OR c.CourseCode = @CourseCode)
      AND (@TitleKeyword IS NULL OR c.CourseTitle LIKE '%' + @TitleKeyword + '%')
      AND (@DepartmentID IS NULL OR c.DepartmentID = @DepartmentID)
      AND (@MinCreditHours IS NULL OR c.CreditHours >= @MinCreditHours)
      AND (@MaxCreditHours IS NULL OR c.CreditHours <= @MaxCreditHours)
    ORDER BY c.CourseCode;
END;
GO

-- ============================================================
-- Test it - search by title keyword only
-- ============================================================
EXEC SearchCourses @TitleKeyword = 'Database';
GO

-- ============================================================
-- Test it - search by department only
-- ============================================================
EXEC SearchCourses @DepartmentID = 1;
GO

-- ============================================================
-- Test it - combine filters
-- ============================================================
EXEC SearchCourses @DepartmentID = 1, @MinCreditHours = 3, @MaxCreditHours = 3;
GO

-- ============================================================
-- Test it - no filters at all (returns everything)
-- ============================================================
EXEC SearchCourses;
GO

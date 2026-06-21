-- ============================================================
-- MODULE 6: COMMON TABLE EXPRESSIONS (CTEs)
-- File: database/views/advanced_sql_ctes.sql
-- 1. Recursive CTE for course prerequisite chains
-- 2. Regular CTE for top-ranked student per department
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- PART A: RECURSIVE CTE — Course Prerequisite Chain
-- 
-- The Courses table has a self-referencing FK:
--   PrerequisiteCourseID -> CourseID
-- 
-- A recursive CTE has two parts joined by UNION ALL:
--   1. Anchor: the root course(s) with no prerequisite
--   2. Recursive member: joins back to the CTE itself to find
--      the next level of prerequisites
-- 
-- Viva point: SQL Server uses a spool (temp storage) internally
-- for recursive CTEs. MAXRECURSION limits infinite loops.
-- ============================================================

-- Show the full prerequisite chain for all courses
WITH CoursePrereqChain AS
(
    -- ANCHOR: courses that have no prerequisite (root level)
    SELECT
        CourseID,
        CourseCode,
        CourseTitle,
        PrerequisiteCourseID,
        0                        AS Level,
        CAST(CourseCode AS NVARCHAR(500)) AS PrereqPath
    FROM dbo.Courses
    WHERE PrerequisiteCourseID IS NULL

    UNION ALL

    -- RECURSIVE MEMBER: find the next course in the chain
    SELECT
        c.CourseID,
        c.CourseCode,
        c.CourseTitle,
        c.PrerequisiteCourseID,
        cpc.Level + 1,
        CAST(cpc.PrereqPath + ' -> ' + c.CourseCode AS NVARCHAR(500))
    FROM dbo.Courses c
    INNER JOIN CoursePrereqChain cpc ON c.PrerequisiteCourseID = cpc.CourseID
)
SELECT
    CourseID,
    CourseCode,
    CourseTitle,
    Level          AS PrerequisiteDepth,
    PrereqPath     AS FullPrerequisiteChain
FROM CoursePrereqChain
ORDER BY PrereqPath
OPTION (MAXRECURSION 10);  -- safety: no course chain deeper than 10 levels
GO

-- ============================================================
-- Stored version: a procedure to find all prerequisites
-- for a single given course
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.GetCoursePrerequisiteChain
    @TargetCourseID INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH PrereqChain AS
    (
        -- Start from the target course
        SELECT
            CourseID,
            CourseCode,
            CourseTitle,
            PrerequisiteCourseID,
            0 AS Depth
        FROM dbo.Courses
        WHERE CourseID = @TargetCourseID

        UNION ALL

        -- Walk backwards to find what IT requires
        SELECT
            c.CourseID,
            c.CourseCode,
            c.CourseTitle,
            c.PrerequisiteCourseID,
            pc.Depth + 1
        FROM dbo.Courses c
        INNER JOIN PrereqChain pc ON c.CourseID = pc.PrerequisiteCourseID
    )
    SELECT
        CourseID,
        CourseCode,
        CourseTitle,
        Depth AS PrerequisiteLevel,
        CASE Depth
            WHEN 0 THEN '(Target Course)'
            WHEN 1 THEN 'Direct prerequisite'
            ELSE 'Prerequisite of prerequisite (depth ' + CAST(Depth AS NVARCHAR) + ')'
        END AS Relationship
    FROM PrereqChain
    ORDER BY Depth
    OPTION (MAXRECURSION 10);
END
GO

-- Test: find prerequisites for course 3 (which chains back through 2 -> 1)
EXEC dbo.GetCoursePrerequisiteChain @TargetCourseID = 3;
GO

-- ============================================================
-- PART B: REGULAR CTE — Top Student per Department
-- 
-- Regular CTEs (no recursion) improve readability by breaking
-- a complex query into named steps. Without a CTE this would
-- require nested subqueries that are much harder to follow.
-- ============================================================

WITH
-- Step 1: Calculate each student's CGPA using the UDF
StudentCGPA AS
(
    SELECT
        s.StudentID,
        s.FirstName + ' ' + s.LastName  AS StudentName,
        s.RegistrationNo,
        p.ProgramID,
        p.ProgramName,
        d.DepartmentID,
        d.DeptName                      AS DepartmentName,
        dbo.fn_CalculateCGPA(s.StudentID) AS CGPA
    FROM dbo.Students s
    JOIN dbo.Programs  p ON s.ProgramID     = p.ProgramID
    JOIN dbo.Departments d ON p.DepartmentID = d.DepartmentID
    WHERE s.Status = 'Active'
),
-- Step 2: Rank students within each department by CGPA
RankedStudents AS
(
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY DepartmentID ORDER BY CGPA DESC) AS RankInDept
    FROM StudentCGPA
)
-- Step 3: Pull only the top student per department
SELECT
    DepartmentName,
    StudentName,
    RegistrationNo,
    ProgramName,
    CGPA,
    RankInDept
FROM RankedStudents
WHERE RankInDept = 1
ORDER BY DepartmentName;
GO

-- ============================================================
-- PART C: Regular CTE for multi-step fee analysis report
-- (department-wise fee collection vs outstanding)
-- ============================================================

WITH
DeptFeeStructure AS
(
    SELECT
        d.DepartmentID,
        d.DeptName,
        p.ProgramID,
        fs.FeeStructureID,
        (fs.TuitionFee + fs.LabFee + fs.OtherCharges) AS TotalFeePerSemester
    FROM dbo.Departments d
    JOIN dbo.Programs p     ON p.DepartmentID = d.DepartmentID
    JOIN dbo.FeeStructure fs ON fs.ProgramID   = p.ProgramID
),
FeeCollected AS
(
    SELECT
        dfs.DepartmentID,
        dfs.DeptName,
        SUM(dfs.TotalFeePerSemester) AS TotalExpected,
        SUM(fp.AmountPaid)           AS TotalCollected
    FROM DeptFeeStructure dfs
    JOIN dbo.FeePayments fp ON fp.FeeStructureID = dfs.FeeStructureID
    WHERE fp.Status = 'Completed'
    GROUP BY dfs.DepartmentID, dfs.DeptName
)
SELECT
    DeptName                      AS Department,
    TotalExpected                 AS ExpectedRevenue,
    TotalCollected                AS CollectedRevenue,
    TotalExpected - TotalCollected AS Outstanding,
    CAST(TotalCollected * 100.0 / NULLIF(TotalExpected, 0) AS DECIMAL(5,2)) AS CollectionRate_Pct
FROM FeeCollected
ORDER BY Outstanding DESC;
GO
